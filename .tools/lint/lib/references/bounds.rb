# frozen_string_literal: true

module ProjectLint
  module References
    # Capture original token anchors and the complete comment-sensitive source span.
    class Bounds
      attr_reader :occurrences, :outer_opening, :outer_closing

      def initialize(check, references, wrapper)
        @check = check
        @occurrences = references.map do |reference|
          start = check.reference_position(reference)
          [start, check.reference_closing(start.next_code_token)]
        end
        @outer_opening = check.reference_position(wrapper) if wrapper
        @outer_closing = check.reference_closing(outer_opening) if wrapper
      end

      def first
        occurrences.first.first
      end

      def opening
        first.next_code_token
      end

      def closing
        occurrences.last.last
      end

      def span_first
        outer_opening || first
      end

      def span_last
        return outer_closing || closing unless occurrences.length > 1 && !outer_opening

        @check.trailing_reference_tokens(closing).last || closing
      end

      def tokens
        @check.token_span(span_first, span_last)
      end

      def ignored?
        @check.ignored_span?(span_first, span_last)
      end

      def anchors
        { first: first, opening: opening, closing: closing, occurrences: occurrences,
          outer_opening: outer_opening, outer_closing: outer_closing }
      end
    end
  end
end
