# frozen_string_literal: true

module ProjectLint
  module Documentation
    # Plan row spacing and indentation while preserving examples and structured Markdown.
    module RowLayout
      def inspect_block(rows)
        reset_block_state
        rows.each_with_index { |row, index| inspect_row(row, index, rows) }
      end

      def inspect_row(row, index, rows)
        @row = row
        @text = row[:text]
        return if control?(@text)

        if @text.strip.empty?
          inspect_blank_row
        else
          inspect_content(index, rows)
        end
        @previous = row
      end

      def inspect_blank_row
        return if @row[:token] && @text.empty?

        report(@row, 'Separate Puppet Strings sections with a blank comment line (#)', [''])
      end

      def inspect_content(index, rows)
        prepare_tag
        prepare_structure
        prepare_indentation
        check_example(index, rows) if @current_tag == 'example'
        report(@row, 'Keep @summary on one line; move additional explanation to the overview') if @summary_continuation
        format_row
      end

      def check_example(index, rows)
        report(@row, 'Put the example description on the @example line') unless @text.match?(/\A@example\s+\S/)
        following = rows.drop(index + 1).find { |entry| !entry[:text].strip.empty? && !control?(entry[:text]) }
        return if following && !following[:text].start_with?('@')

        report(@row, 'Put example code on indented comment lines below @example')
      end

      def format_row
        prepare_layout_replacement
        inspect_length
        wrap_long_row
        finalize_replacement
        report(@row, @messages.join('; '), @replacement) if @messages.any?
      end

      def prepare_layout_replacement
        @replacement = nil
        @messages = []
        @messages << 'Separate Puppet Strings sections with a blank comment line (#)' if @separator
        @messages << 'Puppet Strings continuation lines must be indented with two spaces' if @wrong_indent
        @replacement = [@prefix + @content] if @wrong_indent && wrapping_allowed?
        @replacement = [@text] if @separator && !@wrong_indent
      end

      def wrapping_allowed?
        !@example && !@structured && !@summary_continuation
      end

      def replacement_exceeds_maximum?
        @messages.any? { |message| message.include?('maximum') } &&
          @replacement&.any? { |line| @row[:indent].length + 2 + line.length > 140 }
      end

      def finalize_replacement
        @replacement = nil if replacement_exceeds_maximum?
        @replacement = [''] + @replacement if @separator && @replacement
      end
    end
  end
end
