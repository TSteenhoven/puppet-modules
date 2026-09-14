# frozen_string_literal: true

module ProjectLint
  module Documentation
    # Distinguish hard limits, preferred widths and legitimate unbreakable literals.
    module LineWidth
      def inspect_length
        @width = manifest_lines[@row[:line] - 1].length
        @atoms = prose_atoms(@content)
        @row[:exception] = @width > 140 && unbreakable_row? && !%w[summary example].include?(@current_tag)
        message = width_message
        return unless message

        @messages << message << wrapping_message
        @replacement = nil
      end

      def unbreakable_row?
        return literal_example?(@content, @row[:indent].length + 4) if @example

        @atoms&.any? { |atom| @row[:indent].length + 2 + @prefix.length + atom.length > 140 }
      end

      def width_message
        ignored = PuppetLint::Data.ignore_overrides.fetch(:'140chars', {}).key?(@row[:line])
        if @width > 140 && !(@row[:exception] && ignored)
          'Puppet Strings documentation exceeds the maximum 140-character line length'
        elsif preferred_width_problem?
          'Puppet Strings documentation exceeds the preferred 120-character line width'
        end
      end

      def preferred_width_problem?
        @width > 120 && !@row[:exception] && !@example && !(@atoms && @atoms.length == 1)
      end

      def wrapping_message
        case @current_tag
        when 'summary' then 'Shorten @summary and move the full description into the overview'
        when 'example' then 'Keep the @example title on one line and shorten it manually'
        else 'Wrap documentation across comment lines; preserve literal values and example code'
        end
      end

      def wrap_long_row
        return unless @width > 120 && wrapping_allowed?

        if @current_tag == 'param'
          wrap_parameter
        elsif !@current_tag
          wrapped = wrap_prose(@content, @row[:indent].length + 2 + @prefix.length)
          @replacement = wrapped.map { |line| @prefix + line } if wrapped
        end
      end

      def wrap_parameter
        header = @content.match(/\A(@param\s+(?:\[[^\]]+\]\s+)?\w+)\s+(.+)\z/)
        wrapped = header && wrap_prose(header[2], @row[:indent].length + 4)
        @replacement = [header[1]] + wrapped.map { |line| "  #{line}" } if wrapped
      end
    end
  end
end
