# frozen_string_literal: true

require_relative 'array_plans'

module ProjectLint
  module Layout
    # Check only element starts and closing brackets, preserving multiline literal contents.
    module ArrayIndentation
      def check_array_line_indentation(line, column, expected, part, plan)
        prefix = PuppetLint::Data.manifest_lines[line - 1][0, column - 1]
        return unless prefix.match?(/\A[ \t]*\z/)
        return if prefix == ' ' * expected

        report_edit("Use #{expected} leading spaces for #{part}", line, column, arrays: plan)
      end

      def check_array_indentation
        planner = ArrayPlans.new(self, @positions)
        planner.plans.each { |plan| inspect_array_plan(plan, planner.group(plan)) }
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
    end
  end
end
