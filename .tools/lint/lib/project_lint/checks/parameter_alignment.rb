# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/token_helpers'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Align parameter names and defaults against live token widths across a complete block.
    module ParameterAlignment
      include AstCheck
      include TokenHelpers

      def report_alignment(parameter, message, block)
        notify(:warning, message: message, line: parameter.line, column: parameter.column, edit: block)
      end

      def check
        @blocks ||= parameter_blocks
        @blocks.each_with_index do |entries, block|
          name_column, equals_column = alignment_columns(entries)
          entries.each { |entry| check_entry(entry, name_column, equals_column, block) }
        end
      end

      def check_entry(entry, name_column, equals_column, block)
        variable = entry[:variable]
        if line_prefix(variable).length + 1 != name_column
          report_alignment(variable, 'Align parameter names after the widest type across the complete parameter block',
                           block)
        end
        check_default(entry, equals_column, block) if entry[:equals]
      end

      def check_default(entry, column, block)
        equals = entry[:equals]
        if equals.type != :EQUALS || line_prefix(equals).length + 1 != column
          report_alignment(entry[:variable], 'Align parameter equals signs across the complete parameter block', block)
        elsif wrong_default_gap?(equals, column)
          report_alignment(entry[:variable], 'Use one space between the aligned equals sign and a same-line default',
                           block)
        end
      end

      def wrong_default_gap?(equals, column)
        following = code_after(equals)
        following.line == equals.line && line_prefix(following).length + 1 != column + 2
      end

      def type_end_column(entry)
        token = entry[:type_end]
        line_prefix(token).length + token.to_manifest.length + 2
      end

      def alignment_columns(block)
        name = block.map { |entry| type_end_column(entry) }.max
        [name, name + block.map { |entry| entry[:variable].to_manifest.length }.max + 1]
      end

      def fix_problems
        return super if @problems.any? { |problem| problem[:check] == :syntax }

        # Earlier quote, tab or comma fixes may change even previously aligned widths.
        # Rerun on the saved anchors; native run and fix_problems retain lint:ignore handling.
        @problems = []
        run
        super
      end

      def fix(problem)
        block = @blocks.fetch(problem[:edit])
        raise PuppetLint::NoFix if inline_parameters?(block)
        raise PuppetLint::NoFix if ignored_span?(block.first[:type_start], block.last[:variable])

        block.each { |entry| validate_alignment(entry) }
        name_column, equals_column = alignment_columns(block)
        block.each { |entry| align_parameter(entry, name_column, equals_column) }
      end

      def inline_parameters?(block)
        block.length > 1 && block.any? { |entry| !line_prefix(entry[:type_start]).match?(/\A[ \t]*\z/) }
      end

      def validate_alignment(entry)
        raise PuppetLint::NoFix unless whitespace_gap?(entry[:type_end], entry[:variable])

        equals = entry[:equals]
        validate_default_gap(entry[:variable], equals) if equals
      end

      def validate_default_gap(variable, equals)
        raise PuppetLint::NoFix unless equals.type == :EQUALS && whitespace_gap?(variable, equals)

        following = code_after(equals)
        raise PuppetLint::NoFix if following.line == equals.line && !whitespace_gap?(equals, following)
      end

      def align_parameter(entry, name_column, equals_column)
        type_end, variable = entry.values_at(:type_end, :variable)
        width = name_column - line_prefix(type_end).length - type_end.to_manifest.length - 1
        set_whitespace(type_end, variable, width)
        align_default(entry, name_column, equals_column) if entry[:equals]
      end

      def align_default(entry, name_column, equals_column)
        variable, equals = entry.values_at(:variable, :equals)
        set_whitespace(variable, equals, equals_column - name_column - variable.to_manifest.length)
        following = code_after(equals)
        set_whitespace(equals, following, 1) if following.line == equals.line
      end

      def parameter_blocks
        @positions = tokens.to_h { |token| [[token.line, token.column], token] }
        ast.declarations.filter_map do |declaration|
          parameters = declaration.parameters
          next if parameters.empty? || parameters.any? { |parameter| parameter.type_expr.nil? }

          parameters.map { |parameter| parameter_entry(parameter) }
        end
      end

      def parameter_entry(parameter)
        variable = @positions.fetch([parameter.line, parameter.pos])
        type = parameter.type_expr
        { variable: variable, type_start: @positions.fetch([type.line, type.pos]),
          type_end: variable.prev_code_token, equals: parameter.value ? variable.next_code_token : nil }
      end
    end
    PuppetLint.new_check(:project_parameter_alignment) { include ParameterAlignment }
  end
end
