# frozen_string_literal: true

module ProjectLint
  module Layout
    # Apply layout edits through the linter's native token lifecycle and suppression checks.
    module Fixes
      def fix(problem)
        edit = @edits.fetch(problem[:edit])
        if edit[:arrays]
          fix_arrays(edit[:arrays])
        elsif edit[:remove]
          remove_blank_lines(edit[:remove])
        elsif edit[:comma]
          fix_comma_gap(edit)
        else
          fix_parameter_comma(edit[:closing])
        end
      end

      def remove_blank_lines(blank)
        raise PuppetLint::NoFix if ignored_span?(blank.first, blank.last)

        blank.each { |token| remove_token(token) if tokens.include?(token) }
      end

      def fix_comma_gap(edit)
        raise PuppetLint::NoFix if ignored_span?(edit[:comma], edit[:following])

        set_whitespace(edit[:comma], code_after(edit[:comma]), 1)
      end

      def trailing_parameter_token(closing)
        index = tokens.index(closing)
        raise PuppetLint::NoFix unless index

        last = tokens.take(index).reverse.find { |token| !PuppetLint::Data.formatting_tokens.include?(token.type) }
        # A detached heredoc terminator cannot act as the parameter separator.
        raise PuppetLint::NoFix if last.type.to_s.start_with?('HEREDOC')

        last
      end

      def fix_parameter_comma(closing)
        last = trailing_parameter_token(closing)
        return if last.type == :COMMA

        add_token(tokens.index(last) + 1, PuppetLint::Lexer::Token.new(:COMMA, ',', last.line, last.column))
      end
    end
  end
end
