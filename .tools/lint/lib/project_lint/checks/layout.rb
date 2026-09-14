# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/token_helpers'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Coordinate array, brace and comma layout checks using original source positions.
    module Layout
      include AstCheck
      include TokenHelpers

      def report_edit(message, line, column, edit)
        @edits << edit
        notify(:warning, message: message, line: line, column: column, edit: @edits.length - 1)
      end

      def check
        @edits = []
        @positions = tokens.to_h { |token| [[token.line, token.column], token] }
        check_array_indentation
        check_opening_brace_spacing
        check_commas
        (class_indexes + defined_type_indexes).each { |declaration| check_parameter_comma(declaration) }
      end

      def check_commas
        tokens.each { |token| check_comma_gap(token) if token.type == :COMMA && token.next_code_token }
      end

      def check_comma_gap(token)
        following = token.next_code_token
        return if following.line != token.line || %i[RBRACK RBRACE RPAREN].include?(following.type)
        return if token.next_token.type == :WHITESPACE && token.next_token.value == ' '

        report_edit('Use one space after a same-line comma', token.line, token.column, comma: token,
                                                                                       following: following)
      end

      def multiline_parameter_end(declaration, parameters)
        code = parameters.reject { |token| PuppetLint::Data.formatting_tokens.include?(token.type) }
        last = code.last
        last if last && declaration[:name_token].line != last.line && last.type != :COMMA
      end

      def check_parameter_comma(declaration)
        parameters = declaration[:param_tokens]
        return unless parameters&.any?

        last = multiline_parameter_end(declaration, parameters)
        return unless last

        report_edit('End a multiline parameter block with a trailing comma', last.line, last.column,
                    closing: parameters.last.next_token)
      end

      # Inspect and correct grouped nested arrays using original token anchors.
      module ArrayIndentation
        def check_array_line_indentation(line, column, expected, part, plan)
          prefix = PuppetLint::Data.manifest_lines[line - 1][0, column - 1]
          return unless prefix.match?(/\A[ \t]*\z/)
          return if prefix == ' ' * expected

          report_edit("Use #{expected} leading spaces for #{part}", line, column, arrays: plan)
        end

        def check_array_indentation
          @closings = bracket_closings
          @array_layouts = ast.each_node(Ast::M::LiteralList).filter_map { |node, parents| array_layout(node, parents) }
          @array_layouts.each { |plan| inspect_array_plan(plan, array_group(plan)) }
        end

        def source_array_indent(plan)
          PuppetLint::Data.manifest_lines[plan[:node].line - 1][/\A[ \t]*/].gsub("\t", '  ').length + plan[:extra]
        end

        def inspect_array_plan(plan, group)
          indent = source_array_indent(plan)
          elements = plan[:node].values
          elements.each do |value|
            check_array_line_indentation(value.line, value.pos, indent + 2, 'the array element', group)
          end
          closing = plan[:closing]
          check_array_line_indentation(closing.line, closing.column, indent, 'the closing array bracket', group)
        end

        def fix_arrays(plans)
          raise PuppetLint::NoFix if ignored_span?(plans.first[:opening], plans.first[:closing])

          plans.each do |plan|
            plan_widths(plan).each { |token, width| fix_array_token(token, width) }
          end
        end

        def plan_widths(plan)
          indent = line_prefix(plan[:opening])[/\A[ \t]*/].gsub("\t", '  ').length + plan[:extra]
          plan[:elements].map { |token| [token, indent + 2] } + [[plan[:closing], indent]]
        end

        def indentation_anchor(token)
          index = tokens.index(token) - 1
          index -= 1 while index >= 0 && %i[INDENT WHITESPACE].include?(tokens[index].type)
          raise PuppetLint::NoFix unless index >= 0 && tokens[index].type == :NEWLINE

          tokens[index]
        end

        def fix_array_token(token, width)
          # only_variable_string removes the quote anchor but retains its variable.
          token = token.next_token while token && !tokens.include?(token)
          raise PuppetLint::NoFix unless token
          return unless line_prefix(token).match?(/\A[ \t]*\z/)

          set_whitespace(indentation_anchor(token), token, width, :INDENT)
        end

        def array_layout(node, parents)
          opening = @positions.fetch([node.line, node.pos])
          closing = @closings[opening]
          return unless closing && closing.line > node.line

          { node: node, opening: opening, closing: closing, extra: resource_indent(node, parents),
            elements: node.values.map { |value| @positions.fetch([value.line, value.pos]) } }
        end

        def resource_indent(node, parents)
          parents.last.is_a?(Ast::M::ResourceBody) && parents[-2].line == node.line ? 2 : 0
        end

        def covers?(parent, child)
          parent.offset <= child.offset && parent.offset + parent.length >= child.offset + child.length
        end

        def array_group(plan)
          outer = @array_layouts.find { |candidate| covers?(candidate[:node], plan[:node]) }
          @array_layouts.select { |candidate| covers?(outer[:node], candidate[:node]) }
        end
      end

      def inline_brace_comment?(token, opening)
        token && token.line == opening.line && %i[WHITESPACE COMMENT SLASH_COMMENT MLCOMMENT].include?(token.type) &&
          !token.value.include?("\n")
      end

      def opening_newline(opening)
        following = opening.next_token
        following = following.next_token while inline_brace_comment?(following, opening)
        following if following&.type == :NEWLINE && following.line == opening.line
      end

      def blank_tokens(cursor)
        blank = []
        while cursor && %i[INDENT WHITESPACE NEWLINE].include?(cursor.type)
          blank << cursor
          cursor = cursor.next_token
        end
        blank.pop while blank.last && blank.last.type != :NEWLINE
        blank
      end

      def check_opening_brace_spacing
        tokens.select { |token| token.type == :LBRACE }.each do |opening|
          following = opening_newline(opening)
          next unless following && PuppetLint::Data.manifest_lines[opening.line]&.strip == ''

          report_edit('Remove blank lines immediately after an opening brace', opening.line + 1, 1,
                      remove: blank_tokens(following.next_token))
        end
      end

      def fix(problem)
        edit = @edits.fetch(problem[:edit])
        if edit[:arrays]
          fix_arrays(edit[:arrays])
        elsif edit[:remove]
          remove_blank_lines(edit[:remove])
        elsif edit[:comma]
          fix_comma_gap(edit)
        else
          fix_parameter_comma(edit[:closing])
        end
      end

      def remove_blank_lines(blank)
        raise PuppetLint::NoFix if ignored_span?(blank.first, blank.last)

        blank.each { |token| remove_token(token) if tokens.include?(token) }
      end

      def fix_comma_gap(edit)
        raise PuppetLint::NoFix if ignored_span?(edit[:comma], edit[:following])

        set_whitespace(edit[:comma], code_after(edit[:comma]), 1)
      end

      def trailing_parameter_token(closing)
        index = tokens.index(closing)
        raise PuppetLint::NoFix unless index

        last = tokens.take(index).reverse.find { |token| !PuppetLint::Data.formatting_tokens.include?(token.type) }
        # A detached heredoc terminator cannot act as the parameter separator.
        raise PuppetLint::NoFix if last.type.to_s.start_with?('HEREDOC')

        last
      end

      def fix_parameter_comma(closing)
        last = trailing_parameter_token(closing)
        return if last.type == :COMMA

        add_token(tokens.index(last) + 1, PuppetLint::Lexer::Token.new(:COMMA, ',', last.line, last.column))
      end

      include ArrayIndentation
    end
    PuppetLint.new_check(:project_layout) { include Layout }
  end
end
