# frozen_string_literal: true

module ProjectLint
  module References
    # Apply reference edits with native token operations after all removal spans are validated.
    module Fixes
      def fix(problem)
        edit = @fixes.fetch(problem[:edit])
        raise PuppetLint::NoFix unless edit[:fixable]

        removals = reference_removals(edit)
        unwrap_reference(edit) if edit[:outer_opening]
        apply_titles(edit, removals) if edit[:change_titles]
      end

      def reference_removals(edit)
        edit[:occurrences].drop(1).map do |first, last|
          comma = first.prev_code_token
          raise PuppetLint::NoFix unless comma&.type == :COMMA

          token_span(comma, last)
        end
      end

      def apply_titles(edit, removals)
        ordered = ordered_title_tokens(edit)
        if edit[:merged]
          merge_titles(edit, ordered, removals)
        else
          sort_titles(edit, ordered)
        end
      end

      def ordered_title_tokens(edit)
        entries = edit[:titles].each_with_index.sort_by { |(title, _token), index| [title.value, index] }
        entries.map { |(_title, token), _index| token }
      end

      def sort_titles(edit, ordered)
        original = edit[:titles].map(&:last)
        slots = original.map { |token| tokens.index(token) }
        original.each { |token| remove_token(token) }
        slots.zip(ordered).each { |index, token| add_token(index, token) }
      end

      def unwrap_shift(edit)
        prefix = line_prefix(edit[:first])
        indent = line_prefix(edit[:outer_opening])[/\A[ \t]*/]
        prefix.match?(/\A[ \t]*\z/) ? [prefix.length - indent.length, 0].max : 0
      end

      def unwrap_reference(edit)
        shift = unwrap_shift(edit)
        unindent_reference(edit, shift) if shift.positive?
        token_span(edit[:outer_opening], edit[:first])[0...-1].each { |token| remove_token(token) }
        token_span(edit[:closing], edit[:outer_closing])[1..].each { |token| remove_token(token) }
      end

      def unindent_reference(edit, shift)
        token_span(edit[:first], edit[:closing]).each_cons(2) do |previous, token|
          next unless previous.type == :NEWLINE && %i[INDENT WHITESPACE].include?(token.type)

          token.value = token.value.sub(/\A {1,#{shift}}/, '')
        end
      end

      def merge_titles(edit, ordered, removals)
        opening = edit[:opening]
        closing = edit[:occurrences].first.last
        interior = token_span(opening, closing)[1...-1]
        replacement = render_titles(edit, closing, ordered)
        (interior + removals.flatten).each { |token| remove_token(token) }
        insert_tokens_after(opening, replacement)
      end

      def render_titles(edit, closing, ordered)
        multiline = edit[:opening].line != (edit[:outer_opening] ? edit[:closing] : closing).line
        indent = line_prefix(edit[:opening])[/\A[ \t]*/]
        separator = multiline ? ",\n#{indent}  " : ', '
        replacement = separated_titles(ordered, separator)
        return replacement unless multiline

        lex_reference("\n#{indent}  ") + replacement + lex_reference(",\n#{indent}")
      end

      def separated_titles(ordered, separator)
        ordered.each_with_index.flat_map do |token, index|
          prefix = index.positive? ? lex_reference(separator) : []
          [*prefix, token]
        end
      end

      def lex_reference(text)
        PuppetLint::Lexer.new.tokenise(text)
      end
    end
  end
end
