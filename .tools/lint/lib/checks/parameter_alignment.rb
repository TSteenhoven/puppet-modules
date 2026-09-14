# frozen_string_literal: true

require_relative '../model'
require_relative '../token_helpers'
require_relative '../parameter_blocks'
require_relative '../parameters/alignment_fixes'

module ProjectLint
  # Align parameter names and defaults against live token widths across a complete block.
  module ParameterAlignmentCheck
    include ModelCheck
    include TokenHelpers
    include Parameters::AlignmentFixes

    def report_alignment(parameter, message, block)
      notify(:warning, message: message, line: parameter.line, column: parameter.column, edit: block)
    end

    def check
      @blocks ||= ParameterBlocks.new(model, tokens).blocks
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
  end
end
