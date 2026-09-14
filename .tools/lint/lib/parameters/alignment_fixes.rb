# frozen_string_literal: true

module ProjectLint
  module Parameters
    # Validate every alignment gap before applying changes to a parameter block.
    module AlignmentFixes
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
    end
  end
end
