# frozen_string_literal: true

module ProjectLint
  module Documentation
    # Maintain tag, fence and example context while reading one documentation block.
    module RowState
      def reset_block_state
        @previous = nil
        @tag = nil
        @literal = nil
        @structured_section = false
        @example_started = false
      end

      def prepare_tag
        @current_tag = @literal ? nil : @text[/\A@(\w+)\b/, 1]
        reset_section if @current_tag
        @separator = separator_needed?
        @tag = @current_tag if @current_tag
        @tag = nil if @separator && !@current_tag
        @tag = nil if summary_overview?
      end

      def reset_section
        @structured_section = false
        @example_started = false
      end

      def separator_needed?
        return false unless @previous && !@previous[:text].strip.empty?

        @current_tag || (@tag == 'summary' && !@text.start_with?(' '))
      end

      def summary_overview?
        @tag == 'summary' && @previous && @previous[:text].strip.empty? &&
          !@text.start_with?(' ') && !@current_tag
      end

      def prepare_structure
        @continuation = !@current_tag && @tag
        @prefix = @continuation ? '  ' : ''
        @content = @text.lstrip
        fence = @content[/\A(`{3,}|~{3,})/, 1]
        @structured_section ||= structured_content?(fence)
        @structured = @literal || @structured_section || @text.end_with?('  ', '\\')
        update_fence(fence) if fence
      end

      def structured_content?(fence)
        fence || structured_prose?(@content) || @text.start_with?(@continuation ? '      ' : '    ')
      end

      def update_fence(fence)
        if @literal
          @literal = nil if fence[0] == @literal[0] && fence.length >= @literal.length && @content.strip == fence
        else
          @literal = fence
        end
      end

      def prepare_indentation
        @example = @continuation && @tag == 'example'
        @wrong_indent = @continuation && !@text.start_with?('  ')
        @wrong_indent ||= initial_example_indent?
        @example_started = true if @example
        @wrong_indent ||= extra_continuation_indent?
        @summary_continuation = @continuation && @tag == 'summary'
      end

      def initial_example_indent?
        @example && !@example_started && @text[/\A */].length != 2
      end

      def extra_continuation_indent?
        @continuation && !@example && !@structured && @text.start_with?('   ') && !@text.start_with?('      ')
      end
    end
  end
end
