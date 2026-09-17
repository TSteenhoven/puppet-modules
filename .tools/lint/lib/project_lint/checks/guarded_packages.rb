# frozen_string_literal: true

require 'project_lint/parameter_source'
require 'project_lint/section_layout'
require 'project_lint/token_helpers'

module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Combine matching declarations and let stdlib report conflicting package attributes.
    module GuardedPackages
      # Recognize the guard and compare attributes through the shared Puppet AST.
      module Detection
        def guarded_title(test)
          test = @values.unwrap(test)
          return unless test.is_a?(Ast::M::NotExpression)

          call = @values.unwrap(test.expr)
          return unless defined_call?(call)

          reference = @values.unwrap(call.arguments.first)
          return unless package_reference?(reference)

          literal_title(reference.keys.first)
        end

        def defined_call?(call)
          call.is_a?(Ast::M::CallNamedFunctionExpression) &&
            %w[defined ::defined].include?(call.functor_expr.value) && call.arguments.one? && !call.lambda
        end

        def package_reference?(reference)
          reference.is_a?(Ast::M::AccessExpression) && reference.keys.one? &&
            ast.named_type?(reference.left_expr, 'Package')
        end

        def literal_title(node)
          value = @values.literal(node)
          value.first if value && value.first.is_a?(String) && !value.first.empty?
        end

        def statements(node)
          node.is_a?(Ast::M::BlockExpression) ? node.statements : [node].compact
        end

        def candidate(node, parents)
          return if node.is_a?(Ast::M::UnlessExpression)

          scope = ast.scope_of(parents)
          return unless ast.declarations.any? { |declaration| declaration.equal?(scope) }

          title = guarded_title(node.test)
          resource = guarded_resource(node, title) if title
          return unless resource

          { node: node, parents: parents, scope: scope, resource: resource, title: title,
            attributes: resource.bodies.first.operations.sort_by(&:attribute_name) }
        end

        def guarded_resource(node, title)
          resources = statements(node.then_expr).grep(Ast::M::ResourceExpression).select do |resource|
            resource.type_name.value == 'package'
          end
          return unless resources.one?

          resource = resources.first
          return unless resource.bodies.one? && matching_body?(resource.bodies.first, title)

          resource
        end

        def matching_body?(body, title)
          literal_title(body.title) == title && body.operations.all? { |op| ordinary_attribute?(op) }
        end

        def ordinary_attribute?(operation)
          operation.is_a?(Ast::M::AttributeOperation) && operation.operator == '=>'
        end

        def signature(entry)
          entry[:attributes].map do |attribute|
            value = @values.literal(attribute.value_expr)
            [attribute.attribute_name, value ? [:literal, value] : [:expression, attribute.value_expr]]
          end
        end

        def groups
          candidates = ast.each_node(Ast::M::IfExpression).filter_map { |node, parents| candidate(node, parents) }
          # Identity keeps equal-looking blocks in different branches or declarations separate.
          candidates.group_by { |entry| group_scope(entry) }.values.flat_map do |entries|
            entries.group_by { |entry| signature(entry) }.values.select { |group| group.length > 1 }
          end
        end

        def group_scope(entry)
          parent = entry[:parents].last
          parent = entry[:node] if parent.is_a?(Ast::M::IfExpression)
          [entry[:scope].object_id, parent.object_id]
        end
      end

      # Refuse an entire group when execution, defaults or token ownership are uncertain.
      module Safety
        def simple_entry?(entry)
          node = entry[:node]
          resource = entry[:resource]
          entry[:parents].last.is_a?(Ast::M::BlockExpression) && node.else_expr.nil? &&
            statements(node.then_expr).one? && resource.form == 'regular' &&
            safe_attributes?(entry[:attributes]) && unused_result?(entry)
        end

        def unused_result?(entry)
          entry[:parents].drop_while { |parent| !parent.equal?(entry[:scope]) }.drop(1).all? do |parent|
            parent.is_a?(Ast::M::BlockExpression) || parent.is_a?(Ast::M::IfExpression)
          end
        end

        def safe_attributes?(attributes)
          names = attributes.map(&:attribute_name)
          installed?(attributes) && names.uniq == names &&
            (names & %w[require before notify subscribe alias name]).empty? &&
            attributes.all? { |attribute| @values.literal(attribute.value_expr) }
        end

        def installed?(attributes)
          ensure_value = attributes.find { |attribute| attribute.attribute_name == 'ensure' }
          # ensure_packages adds installed when absent and normalizes present; neither is an exact rewrite.
          ensure_value && @values.literal(ensure_value.value_expr) == ['installed']
        end

        def contextual_attributes?(group)
          inherited = group.first[:parents].any? do |parent|
            parent.is_a?(Ast::M::HostClassDefinition) && parent.parent_class
          end
          inherited || ast.nodes.any? do |node, _parents|
            node.is_a?(Ast::M::ResourceDefaultsExpression) || node.is_a?(Ast::M::ResourceOverrideExpression) ||
              node.is_a?(Ast::M::CollectExpression)
          end
        end

        def consecutive?(group)
          parent = group.first[:parents].last
          return false unless parent.is_a?(Ast::M::BlockExpression)

          indexes = group.map { |entry| parent.statements.index { |node| node.equal?(entry[:node]) } }
          indexes.none?(&:nil?) && indexes == (indexes.first..indexes.last).to_a
        end

        def safe_group?(group)
          group.all? { |entry| simple_entry?(entry) && entry[:title].match?(/\A[a-zA-Z0-9][a-zA-Z0-9+_.:-]*\z/) } &&
            consecutive?(group) && !contextual_attributes?(group) &&
            group.map { |entry| entry[:title] }.uniq.length == group.length
        end

        def safe_tokens?(first, last)
          !ignored_span?(first, last) && token_span(first, last).none? do |token|
            %i[COMMENT SLASH_COMMENT MLCOMMENT HEREDOC_OPEN].include?(token.type)
          end
        end
      end

      # Build one replacement using current native tokens, after earlier lint fixes have run.
      module Replacement
        def position(node)
          @positions.fetch([node.line, node.pos])
        end

        def closing(node)
          position(node).next_token_of(:LBRACE).next_token_of(:RBRACE)
        end

        def value_tokens(attribute)
          key = position(attribute)
          delimiter = key.next_token_of(%i[COMMA RBRACE])
          token_span(key.next_code_token.next_code_token, delimiter.prev_code_token)
        end

        def literal_text(attribute)
          value_tokens(attribute).map do |token|
            if token.type == :NAME
              PuppetLint::Lexer::Token.new(:SSTRING, token.value, token.line, token.column).to_manifest
            else
              token.to_manifest
            end
          end.join
        end

        def replacement(group, indent)
          titles = group.map { |entry| "#{indent}    '#{entry[:title]}',\n" }.join
          settings = settings_text(group.first[:attributes], indent)
          "ensure_packages(\n#{indent}  [\n#{titles}#{indent}  ],\n" \
            "#{indent}  {\n#{settings}#{indent}  },\n#{indent})"
        end

        def settings_text(attributes, indent)
          width = attributes.map { |attribute| attribute.attribute_name.length }.max
          attributes.map do |attribute|
            key = "'#{attribute.attribute_name}'".ljust(width + 2)
            "#{indent}    #{key} => #{literal_text(attribute)},\n"
          end.join
        end

        def prepared_replacement(edit)
          first, last = edit.values_at(:first, :last)
          raise PuppetLint::NoFix unless safe_tokens?(first, last)

          indent = line_prefix(first)
          raise PuppetLint::NoFix unless indent.match?(/\A *\z/) && last.next_token&.type == :NEWLINE

          text = replacement(edit[:group], indent)
          validate_replacement(text, edit[:group])
          PuppetLint::Lexer.new.tokenise(text)
        end

        def validate_replacement(text, group)
          raise PuppetLint::NoFix if text.lines.any? { |line| line.chomp.length > 140 }
          raise PuppetLint::NoFix if group.first[:attributes].any? do |attribute|
            value_tokens(attribute).any? { |token| token.to_manifest.include?("\n") }
          end
        end

        def fixable_edit?(edit)
          return false unless safe_group?(edit[:group])

          prepared_replacement(edit)
          true
        rescue PuppetLint::NoFix
          false
        end
      end

      include SectionLayout
      include TokenHelpers
      include Detection
      include Safety
      include Replacement

      def check
        @positions = token_positions
        @values = ParameterSource.new(ast)
        @edits = []
        groups.each { |group| report_group(group) }
      end

      def report_group(group)
        first = position(group.first[:node])
        last = closing(group.last[:node])
        edit = { group: group, first: first, last: last }
        edit[:safe] = fixable_edit?(edit)
        @edits << edit
        notify(:warning, message: group_message(edit), line: first.line, column: first.column, edit: @edits.length - 1)
      end

      def group_message(edit)
        names = edit[:group].map { |entry| entry[:title].dump.delete_prefix('"').delete_suffix('"') }
        message = "Multiple guarded package declarations can be combined using ensure_packages(): #{names.join(', ')}"
        message += ' [review] Verify evaluation order, attributes, relationships and comments' unless edit[:safe]
        message
      end

      def fix(problem)
        edit = @edits.fetch(problem[:edit])
        # Earlier whitespace fixes can make a previously uneditable token span usable.
        raise PuppetLint::NoFix unless safe_group?(edit[:group])

        replacement = prepared_replacement(edit)
        replace_group(edit, replacement)
      end

      def replace_group(edit, replacement)
        originals = token_span(edit[:first], edit[:last])
        index = tokens.index(edit[:first])
        originals.each { |token| remove_token(token) }
        replacement.each_with_index { |token, offset| add_token(index + offset, token) }
      end
    end
    PuppetLint.new_check(:project_guarded_packages) { include GuardedPackages }
  end
end
