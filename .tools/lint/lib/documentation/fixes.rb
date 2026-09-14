# frozen_string_literal: true

module ProjectLint
  module Documentation
    # Apply approved edits using native tokens and keep anchors available to other checks.
    module Fixes
      def replace_line(token, replacement)
        # Native insertion at index zero requires an existing preceding token.
        token.value = replacement.shift.value
        index = tokens.index(token)
        replacement.each_with_index { |new_token, offset| add_token(index + 1 + offset, new_token) }
      end

      def fix(problem)
        edit = @edits.fetch(problem[:edit])
        return remove_directives(edit[:remove]) if edit[:remove]

        raise PuppetLint::NoFix unless edit[:replacement]

        replace_documentation_row(edit[:row], edit[:replacement])
      end

      def remove_directives(pair)
        raise PuppetLint::NoFix if ignored_span?(*pair)

        pair.each do |token|
          previous = token.prev_token
          following = token.next_token
          remove_token(previous) if previous&.type == :INDENT
          remove_token(following) if following&.type == :NEWLINE
          remove_token(token)
        end
      end

      def replace_documentation_row(row, replacement)
        rendered = replacement.map { |line| line.empty? ? '#' : "# #{line}" }.join("\n#{row[:indent]}")
        if row[:token]
          replace_line(row[:token], PuppetLint::Lexer.new.tokenise(rendered))
        else
          insert_comment(row)
        end
      end

      def insert_comment(row)
        # Preserve the existing newline and indentation of a whitespace-only source line.
        anchor = @source_tokens.find { |token| token.line == row[:line] && token.type == :NEWLINE }
        add_token(tokens.index(anchor), PuppetLint::Lexer.new.tokenise('#').first)
      end
    end
  end
end
