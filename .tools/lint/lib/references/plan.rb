# frozen_string_literal: true

require_relative 'bounds'

module ProjectLint
  module References
    # Prove fix safety and retain actual title tokens, including duplicates and original spelling.
    class Plan
      attr_reader :bounds

      def initialize(check, references, relationship, wrapper, safe_merge:)
        @check = check
        @references = references
        @relationship = relationship
        @wrapper = wrapper
        @safe_merge = safe_merge
        @titles = references.flat_map(&:keys)
        @bounds = Bounds.new(check, references, wrapper)
      end

      def literal?
        @titles.all? { |title| @check.literal_title?(title) }
      end

      def merged?
        @references.length > 1
      end

      def unordered?
        literal? && @titles.map(&:value) != @titles.map(&:value).sort
      end

      def change_titles?
        merged? || unordered?
      end

      def needed?
        change_titles? || @wrapper
      end

      def title_tokens
        literal? ? @titles.map { |title| @check.reference_position(title) } : []
      end

      def movable_titles?
        literal? && title_tokens.all? { |token| %i[SSTRING STRING NAME].include?(token.type) }
      end

      def safe_span?
        !bounds.ignored? && bounds.tokens.none? do |token|
          %i[COMMENT SLASH_COMMENT MLCOMMENT HEREDOC_OPEN].include?(token.type)
        end
      end

      def fixable?
        @relationship && @safe_merge && safe_span? && (!change_titles? || movable_titles?)
      end

      def edit
        bounds.anchors.merge(titles: @titles.zip(title_tokens), fixable: fixable?,
                             merged: merged?, change_titles: change_titles?)
      end

      def base_message
        if merged?
          'Merge references of the same resource type within the array and sort their titles alphabetically'
        elsif unordered?
          'Sort resource reference titles alphabetically'
        else
          'Remove the outer array around a single resource reference'
        end
      end

      def message
        text = base_message
        text += '; remove the outer array around the resulting single reference' if @wrapper && change_titles?
        unless fixable?
          text += ' [review] Verify relationship context, array shape, title order and comments ' \
                  'before changing this expression'
        end
        text
      end
    end
  end
end
