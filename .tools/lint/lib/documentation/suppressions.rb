# frozen_string_literal: true

module ProjectLint
  module Documentation
    # Narrow only exact, bounded documentation-only length suppressions.
    module Suppressions
      def suppression_controls(token)
        token.value.strip.split.take_while { |word| word.start_with?('lint:') }
      end

      def standalone_control?(token)
        %i[COMMENT SLASH_COMMENT MLCOMMENT].include?(token.type) && control?(token.value.strip) &&
          manifest_lines[token.line - 1][0, token.column - 1].strip.empty?
      end

      def inspect_suppressions(rows)
        @rows_by_line = rows.to_h { |row| [row[:line], row] }
        stack = []
        @source_tokens.select { |token| standalone_control?(token) }.each do |token|
          if suppression_controls(token).first == 'lint:endignore'
            inspect_suppression_pair(stack.pop, token)
          else
            stack << token
          end
        end
      end

      def inspect_suppression_pair(opening, closing)
        return unless opening && suppression_controls(opening).include?('lint:ignore:140chars')

        affected = ((opening.line + 1)...closing.line).filter_map { |line| @rows_by_line[line] }
        return unless affected.any? { |row| normal_prose?(row) }

        report_suppression(opening, closing, removable_suppression?(opening, closing, affected))
      end

      def report_suppression(opening, closing, removable)
        @edits << { remove: removable ? [opening, closing] : nil }
        notify(:warning, message: suppression_message(removable), line: opening.line, column: opening.column,
                         edit: @edits.length - 1)
      end

      def normal_prose?(row)
        !row[:text].strip.empty? && !control?(row[:text]) && !row[:exception]
      end

      def removable_suppression?(opening, closing, affected)
        opening.value.strip == 'lint:ignore:140chars' && closing.value.strip == 'lint:endignore' &&
          affected.length == closing.line - opening.line - 1 &&
          affected.none? { |row| row[:exception] || control?(row[:text]) }
      end

      def suppression_message(removable)
        message = 'Do not disable the 140-character rule for normal Puppet Strings documentation; ' \
                  'wrap the documentation instead'
        unless removable
          message += ' [review] Narrow the suppression manually, preserving literal values and other checks'
        end
        message
      end
    end
  end
end
