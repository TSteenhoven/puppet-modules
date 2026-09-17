# frozen_string_literal: true

require 'project_lint/parameter_source'
require 'project_lint/section_layout'
require 'project_lint/token_helpers'
require 'project_lint/resource_values'

module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Compare literal origins and resource types, retaining package-specific installation semantics.
    module ResourceListReuse
      # Follow only syntax whose title-list constituents are known without evaluating Puppet.
      module Sources
        def list_sources(node, seen = [])
          node = @values.unwrap(node)
          return [] if node.nil? || seen.any? { |previous| previous.equal?(node) }
          return [node] if node.is_a?(Ast::M::LiteralList)

          children = source_children(node)
          children.flat_map { |child| list_sources(child, seen + [node]) }
        end

        def source_children(node)
          case node
          when Ast::M::VariableExpression
            [@values.local_value(node, @parents.fetch(node))]
          when Ast::M::ArithmeticExpression
            node.operator == '+' ? [node.left_expr, node.right_expr] : []
          when Ast::M::CallNamedFunctionExpression
            %w[concat ::concat stdlib::concat ::stdlib::concat].include?(node.functor_expr.value) ? node.arguments : []
          else
            conditional_sources(node)
          end
        end

        def conditional_sources(node)
          case node
          when Ast::M::SelectorExpression
            node.selectors.map(&:value_expr)
          when Ast::M::IfExpression
            [node.then_expr, node.else_expr]
          when Ast::M::BlockExpression
            [node.statements.last]
          else
            []
          end
        end

        def installation?(node)
          node.is_a?(Ast::M::CallNamedFunctionExpression) &&
            %w[ensure_packages ::ensure_packages stdlib::ensure_packages
               ::stdlib::ensure_packages].include?(node.functor_expr.value)
        end

        def reference?(node)
          @resource_values.reference?(node)
        end

        def literal_titles(source)
          values = source.is_a?(Ast::M::LiteralList) ? source.values : source.keys
          values.filter_map do |value|
            value.value if value.is_a?(Ast::M::LiteralString) || value.is_a?(Ast::M::QualifiedName)
          end
        end

        def occurrences(node)
          if installation?(node)
            list_sources(node.arguments.first).map { |source| [source, :ensure, 'package'] }
          elsif reference?(node)
            reference_occurrences(node)
          elsif node.is_a?(Ast::M::ResourceExpression)
            declaration_occurrences(node)
          else
            []
          end
        end

        def reference_occurrences(node)
          sources = [node] + node.keys.flat_map { |key| list_sources(key) }
          sources.map { |source| [source, :reference, node.left_expr.value] }
        end

        def declaration_occurrences(node)
          return [] unless node.type_name.is_a?(Ast::M::QualifiedName)

          node.bodies.flat_map do |body|
            list_sources(body.title).map { |source| [source, :declaration, node.type_name.value] }
          end
        end

        def scope(parents)
          ast.scope_of(parents) || parents.find { |parent| parent.is_a?(Ast::M::NodeDefinition) } || ast.program
        end

        def entries
          found = {}
          ast.nodes.each do |node, parents|
            owner = scope(parents)
            next if owner.is_a?(Ast::M::LambdaExpression)

            record_occurrences(found, node, parents, owner)
          end
          found.values.sort_by { |entry| entry[:source].offset }
        end

        def record_occurrences(found, node, parents, owner)
          occurrences(node).each do |source, kind, type|
            names = literal_titles(source)
            next if names.uniq.length < 2

            key = [owner.object_id, source.object_id, type]
            entry = (found[key] ||= { source: source, names: names, scope: owner, type: type, uses: [] })
            entry[:uses] << { node: node, parents: parents, kind: kind }
          end
        end
      end

      # Full declaration sets and substantial near matches justify review; incidental overlap does not.
      module Detection
        def related?(left, right)
          return false unless left[:scope].equal?(right[:scope])
          return false unless left[:type] == right[:type]

          left_names = left[:names].uniq
          right_names = right[:names].uniq
          return true if left_names.sort == right_names.sort

          declaration_overlap?(left, right, left_names, right_names)
        end

        def declaration_overlap?(left, right, left_names, right_names)
          return false if declares?(left) == declares?(right)
          return true if declares?(left) && (left_names - right_names).empty?
          return true if declares?(right) && (right_names - left_names).empty?

          near_match?(left_names, right_names)
        end

        def declares?(entry)
          entry[:uses].any? { |use| use[:kind] != :reference }
        end

        def near_match?(left_names, right_names)
          common = (left_names & right_names).length
          common >= 3 && common * 5 >= left_names.length * 4 && common * 5 >= right_names.length * 4
        end

        def installer?(entry)
          entry[:uses].any? { |use| use[:kind] == :ensure }
        end

        def groups
          remaining = @entries.dup
          result = []
          until remaining.empty?
            group = [remaining.shift]
            remaining = connected_entries(group, remaining)
            result << group.sort_by { |entry| entry[:source].offset } if group.length > 1
          end
          result
        end

        def connected_entries(group, remaining)
          group.each do |member|
            matches, remaining = remaining.partition { |entry| related?(member, entry) }
            group.concat(matches)
          end
          remaining
        end
      end

      # Restrict fixes to one direct call followed by exact literal dependencies in its own block.
      module Safety
        def direct_installation?(entry)
          use = entry[:uses].first
          use[:kind] == :ensure && use[:node].arguments.first.equal?(entry[:source]) && !use[:node].lambda &&
            entry[:source].is_a?(Ast::M::LiteralList)
        end

        def dependency_in_block?(entry, block, call)
          use = entry[:uses].first
          node = use[:node]
          return false unless use[:kind] == :reference && node.equal?(entry[:source]) && node.offset > call.offset

          ancestors = use[:parents].drop_while { |parent| !parent.equal?(block) }.drop(1)
          resource_dependency?(ancestors)
        end

        def resource_dependency?(ancestors)
          return false unless ancestors.first.is_a?(Ast::M::ResourceExpression)
          return false unless ancestors.all? { |parent| dependency_container?(parent) }

          attribute = ancestors.find { |parent| parent.is_a?(Ast::M::AttributeOperation) }
          attribute && %w[require before notify subscribe].include?(attribute.attribute_name)
        end

        def dependency_container?(node)
          [Ast::M::ResourceExpression, Ast::M::ResourceBody, Ast::M::AttributeOperation,
           Ast::M::LiteralList, Ast::M::ParenthesizedExpression].any? { |type| node.is_a?(type) } ||
            @resource_values.concat?(node)
        end

        def safe_group?(group)
          return false unless single_installation_group?(group)

          use = group.first[:uses].first
          block = use[:parents].last
          block.is_a?(Ast::M::BlockExpression) && plain_block?(use[:parents]) &&
            matching_dependencies?(group, block, use[:node])
        end

        def single_installation_group?(group)
          group.all? { |entry| entry[:uses].one? } && direct_installation?(group.first) && sole_installation?(group)
        end

        def sole_installation?(group)
          @entries.one? { |entry| entry[:scope].equal?(group.first[:scope]) && installer?(entry) }
        end

        def matching_dependencies?(group, block, call)
          return false if extensions(group).length > 1

          group.drop(1).all? do |entry|
            (group.first[:names] - entry[:names]).empty? && dependency_in_block?(entry, block, call)
          end
        end

        def extensions(group)
          group.drop(1).map { |entry| (entry[:names] - group.first[:names]).sort }.reject(&:empty?).uniq
        end

        def base_name(group)
          extensions(group).empty? ? 'required_packages' : 'packages'
        end

        def plain_block?(parents)
          parents.all? do |parent|
            [Ast::M::Program, Ast::M::HostClassDefinition, Ast::M::ResourceTypeDefinition,
             Ast::M::BlockExpression, Ast::M::IfExpression, Ast::M::NodeDefinition].any? { |type| parent.is_a?(type) }
          end && parents.none? { |parent| parent.is_a?(Ast::M::HostClassDefinition) && parent.parent_class }
        end

        def name_available?(name)
          ast.nodes.none? do |node, _parents|
            (node.is_a?(Ast::M::VariableExpression) && node.expr.value.split('::').last == name) ||
              (node.is_a?(Ast::M::Parameter) && node.name == name)
          end
        end

        def safe_tokens?(first, last)
          !ignored_span?(first, last) && token_span(first, last).none? do |token|
            %i[COMMENT SLASH_COMMENT MLCOMMENT HEREDOC_OPEN].include?(token.type)
          end
        end

        def literal_tokens(entry)
          first, last = entry.values_at(:opening, :closing)
          raise PuppetLint::NoFix unless first && last && safe_tokens?(first, last)

          interior = token_span(first, last)[1...-1]
          raise PuppetLint::NoFix unless matching_titles?(interior, entry[:names])

          interior
        end

        def matching_titles?(interior, names)
          code = interior.reject { |token| PuppetLint::Data.formatting_tokens.include?(token.type) }
          titles = code.reject { |token| token.type == :COMMA }
          actual = titles.map(&:value)
          titles.all? { |token| package_token?(token) } && actual.sort == names.sort && actual.uniq == actual
        end

        def package_token?(token)
          %i[SSTRING STRING NAME].include?(token.type) && token.value.match?(/\A[a-zA-Z0-9][a-zA-Z0-9+_.:-]*\z/)
        end
      end

      # Prepare every edit before mutating live tokens, after upstream quote and reference fixes.
      module Replacement
        def anchor_entries(group)
          group.map do |entry|
            start = @positions.fetch([entry[:source].line, entry[:source].pos])
            opening = entry[:source].is_a?(Ast::M::LiteralList) ? start : start.next_code_token
            entry.merge(opening: opening, closing: @closings[opening])
          end
        end

        def replacement_plan(group)
          validate_group_names(group)

          call = group.first[:uses].first[:node]
          anchor = @positions.fetch([call.line, call.pos])
          indent = line_prefix(anchor)
          raise PuppetLint::NoFix unless indent.match?(/\A *\z/)

          validate_group_span(anchor, group)
          { anchor: anchor, declaration: declaration_tokens(group, call, indent), group: group,
            extension: extension_plan(group, anchor, indent) }
        end

        def validate_group_names(group)
          raise PuppetLint::NoFix unless safe_group?(group) && name_available?(base_name(group))
          raise PuppetLint::NoFix unless name_available?('required_packages')
        end

        def declaration_tokens(group, call, indent)
          text = declaration_text(group, indent)
          lex("#{declaration_comment(call, indent)}#{text}\n\n#{indent}")
        end

        def declaration_text(group, indent)
          text = group.map { |entry| literal_tokens(entry) }.first.map(&:to_manifest).join
          declaration = "$#{base_name(group)} = [#{text}]"
          raise PuppetLint::NoFix if text.include?("\n") || indent.length + declaration.length > 140

          declaration
        end

        def validate_group_span(anchor, group)
          last = group.last[:closing]
          raise PuppetLint::NoFix unless last
          raise PuppetLint::NoFix if ignored_span?(anchor, last)
          raise PuppetLint::NoFix if token_span(anchor, last).any? { |token| control_comment?(token) }
        end

        def declaration_comment(call, indent)
          return '' if @sections.key?([call.line, call.pos])

          "# Share packages between installation and dependencies.\n#{indent}"
        end

        def fixable?(group)
          replacement_plan(group)
          true
        rescue PuppetLint::NoFix
          false
        end

        def lex(text)
          PuppetLint::Lexer.new.tokenise(text)
        end

        def replace_tokens(originals, replacement)
          index = tokens.index(originals.first)
          originals.each { |token| remove_token(token) }
          replacement.each_with_index { |token, offset| add_token(index + offset, token) }
        end

        def apply_plan(plan)
          index = tokens.index(plan[:anchor])
          plan[:declaration].each_with_index { |token, offset| add_token(index + offset, token) }
          insert_tokens_after(*plan[:extension]) if plan[:extension]
          replace_group(plan[:group])
        end

        def replace_group(group)
          group.each_with_index do |entry, offset|
            replace_list(entry, replacement_name(entry, group), interior: offset.positive?)
          end
        end

        def replacement_name(entry, group)
          entry[:names].sort == group.first[:names].sort ? base_name(group) : 'required_packages'
        end

        def replace_list(entry, name, interior:)
          original = token_span(entry[:opening], entry[:closing])
          original = original[1...-1] if interior
          replace_tokens(original, lex("$#{name}"))
        end
      end

      # Extend package names before constructing resource references or combining other dependencies.
      module Extensions
        def extension_plan(group, anchor, indent)
          extra = extensions(group).first
          return unless extra

          closing = anchor.next_code_token.next_token_of(:RPAREN)
          raise PuppetLint::NoFix unless closing&.next_token&.type == :NEWLINE

          text = extension_text(extra, indent)
          raise PuppetLint::NoFix if text.lines.any? { |line| line.chomp.length > 140 }

          [closing, lex(text)]
        end

        def extension_text(extra, indent)
          names = extra.map { |name| "'#{name}'" }.join(', ')
          "\n\n#{indent}# Include the additional package prerequisites for these resources.\n" \
            "#{indent}$required_packages = concat(\n#{indent}  $packages,\n#{indent}  [#{names}],\n#{indent})"
        end
      end

      include SectionLayout
      include TokenHelpers
      include Sources
      include Detection
      include Safety
      include Replacement
      include Extensions

      def check
        prepare_analysis
        @resource_values = ResourceValues.new(ast)
        @positions = token_positions
        @closings = bracket_closings
        @sections = section_starts
        @edits = []
        @entries = entries
        groups.each { |group| report_group(group) }
      end

      def prepare_analysis
        @values = ParameterSource.new(ast)
        @parents = {}.compare_by_identity
        ast.nodes.each { |node, parents| @parents[node] = parents }
      end

      def report_group(group)
        group = anchor_entries(group)
        message = 'Reuse the resource-title list in a shared variable; ' \
                  'extend it with concat() for additional dependencies'
        unless fixable?(group)
          message += ' [review] Verify overlap, scope, evaluation order and comments before extracting the list'
        end
        @edits << group
        first = group.first[:source]
        notify(:warning, message: message, line: first.line, column: first.pos, edit: @edits.length - 1)
      end

      def fix(problem)
        apply_plan(replacement_plan(@edits.fetch(problem[:edit])))
      end
    end
    PuppetLint.new_check(:project_resource_list_reuse) { include ResourceListReuse }
  end
end
