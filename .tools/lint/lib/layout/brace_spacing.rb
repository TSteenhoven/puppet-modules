# frozen_string_literal: true

module ProjectLint
  module Layout
    # Remove blank source lines after braces without entering comment or string contents.
    module BraceSpacing
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
    end
  end
end
