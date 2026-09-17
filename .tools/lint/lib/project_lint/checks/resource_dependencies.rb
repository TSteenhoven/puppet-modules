# frozen_string_literal: true

require 'project_lint/resource_values'
require 'project_lint/section_layout'
require 'project_lint/token_helpers'

module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Construct resource titles separately from references and other dependency arrays.
    module ResourceDependencies
      # Retain the statement and its execution block for conservative extraction.
      module Detection
        def candidate(node, parents)
          return unless nested_titles?(node)

          block = parents.reverse.find { |parent| parent.is_a?(Ast::M::BlockExpression) }
          index = parents.index { |parent| parent.equal?(block) }
          statement = parents[index + 1] if index
          { node: node, expression: node.keys.first, block: block, statement: statement, parents: parents }
        end

        def nested_titles?(node)
          @values.reference?(node) && node.keys.one? && @values.concat?(node.keys.first)
        end

        def groups
          ast.nodes.filter_map { |node, parents| candidate(node, parents) }
             .group_by { |entry| [entry[:block]&.object_id, entry[:expression]] }.values
        end

        def variable_name(expression)
          variable = ast.references(expression).find { |name| !name.include?('::') }
          return 'required_titles' unless variable

          stem, suffix = variable.match(/\A(?:(.*)_)?([^_]+)\z/).captures
          [stem, 'required', suffix].compact.join('_')
        end

        def available_name?(name)
          !@reserved.include?(name) && ast.nodes.none? do |node, _parents|
            (node.is_a?(Ast::M::VariableExpression) && node.expr.value.split('::').last == name) ||
              (node.is_a?(Ast::M::Parameter) && node.name == name)
          end
        end

        def plain_statement?(entry)
          statement = entry[:statement]
          unless statement.is_a?(Ast::M::ResourceExpression) || statement.is_a?(Ast::M::AssignmentExpression)
            return false
          end

          ancestors = entry[:parents].drop_while { |node| !node.equal?(statement) }
          ancestors.all? { |node| extraction_container?(node) }
        end

        def extraction_container?(node)
          [Ast::M::ResourceExpression, Ast::M::ResourceBody, Ast::M::AttributeOperation, Ast::M::AssignmentExpression,
           Ast::M::LiteralList, Ast::M::ParenthesizedExpression].any? { |type| node.is_a?(type) } ||
            @values.concat?(node)
        end

        def safe_group?(group)
          group.all? { |entry| plain_statement?(entry) && @values.names(entry[:expression]) }
        end
      end

      # Move a known expression using live tokens; never move resource references into title lists.
      module Replacement
        def position(node)
          @positions.fetch([node.line, node.pos])
        end

        def expression_tokens(entry)
          first = position(entry[:expression])
          last = first.next_code_token.next_token_of(:RPAREN)
          raise PuppetLint::NoFix unless last && !ignored_span?(first, last)

          span = token_span(first, last)
          if span.any? { |token| %i[COMMENT MLCOMMENT SLASH_COMMENT HEREDOC_OPEN].include?(token.type) }
            raise PuppetLint::NoFix
          end

          span
        end

        def statement_anchor(entry)
          statement = entry[:statement]
          token = position(statement)
          line = @sections[[statement.line, statement.pos]]
          return token unless line

          tokens.find { |candidate| candidate.line == line && standalone_comment?(candidate) } || token
        end

        def argument_texts(entry)
          opening = position(entry[:expression]).next_code_token
          entry[:expression].arguments.map do |_argument|
            delimiter = opening.next_token_of(%i[COMMA RPAREN])
            text = token_span(opening, delimiter)[1...-1].map(&:to_manifest).join.strip
            raise PuppetLint::NoFix if text.include?("\n")

            opening = delimiter
            text
          end
        end

        def declaration(entry, name, indent)
          arguments = argument_texts(entry).map { |argument| "#{indent}  #{argument},\n" }.join
          text = "# Prepare resource titles before constructing dependencies.\n" \
                 "#{indent}$#{name} = concat(\n#{arguments}#{indent})\n\n#{indent}"
          raise PuppetLint::NoFix if text.lines.any? { |line| line.chomp.length > 140 }

          PuppetLint::Lexer.new.tokenise(text)
        end

        def plan(edit)
          validate_edit(edit)

          group = edit[:group]
          anchor = statement_anchor(group.first)
          spans = group.map { |entry| expression_tokens(entry) }
          validate_span(anchor, spans.last.last)
          { anchor: anchor, spans: spans, declaration: prepared_declaration(edit, anchor) }
        end

        def validate_edit(edit)
          raise PuppetLint::NoFix unless edit[:safe]
          raise PuppetLint::NoFix if tokens.any? do |token|
            token.type == :VARIABLE && token.value.split('::').last == edit[:name]
          end
        end

        def prepared_declaration(edit, anchor)
          indent = line_prefix(anchor)
          raise PuppetLint::NoFix unless indent.match?(/\A *\z/)

          declaration(edit[:group].first, edit[:name], indent)
        end

        def validate_span(first, last)
          raise PuppetLint::NoFix if ignored_span?(first, last)
          raise PuppetLint::NoFix if token_span(first, last).any? { |token| control_comment?(token) }
        end

        def fixable?(edit)
          plan(edit)
          true
        rescue PuppetLint::NoFix
          false
        end

        def replace_expression(span, name)
          index = tokens.index(span.first)
          span.each { |token| remove_token(token) }
          replacement = PuppetLint::Lexer::Token.new(:VARIABLE, name, span.first.line, span.first.column)
          add_token(index, replacement)
        end
      end

      include SectionLayout
      include TokenHelpers
      include Detection
      include Replacement

      def check
        @values = ResourceValues.new(ast)
        @positions = token_positions
        @sections = section_starts
        @reserved = []
        @edits = []
        groups.each { |group| report_group(group) }
      end

      def report_group(group)
        edit = prepare_edit(group)
        @edits << edit
        node = group.first[:node]
        notify(:warning, message: message(edit), line: node.line, column: node.pos, edit: @edits.length - 1)
      end

      def prepare_edit(group)
        name = variable_name(group.first[:expression])
        edit = { group: group, name: name, safe: available_name?(name) && safe_group?(group) }
        edit[:safe] = fixable?(edit)
        @reserved << name if edit[:safe]
        edit
      end

      def message(edit)
        text = 'Prepare the extended title list in a variable before the resource reference; ' \
               'combine other dependencies separately'
        unless edit[:safe]
          text += ' [review] Verify variable contents, conditions, scope and comments before extracting the list'
        end
        text
      end

      def fix(problem)
        edit = @edits.fetch(problem[:edit])
        prepared = plan(edit)
        index = tokens.index(prepared[:anchor])
        prepared[:declaration].each_with_index { |token, offset| add_token(index + offset, token) }
        prepared[:spans].each { |span| replace_expression(span, edit[:name]) }
      end
    end
    PuppetLint.new_check(:project_resource_dependencies) { include ResourceDependencies }
  end
end
