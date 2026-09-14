# frozen_string_literal: true

module ProjectLint
  # Small helpers for native check fixes. Coordinates describe the original input;
  # widths and gaps must use the live tokens after earlier plugins have run.
  module TokenHelpers
    def bracket_closings
      openings = []
      tokens.each_with_object({}) do |token, closings|
        openings << token if token.type == :LBRACK
        closings[openings.pop] = token if token.type == :RBRACK && openings.any?
      end
    end

    def insert_tokens_after(anchor, replacements)
      index = tokens.index(anchor) + 1
      replacements.each_with_index { |token, offset| add_token(index + offset, token) }
    end

    def token_span(first, last)
      start = tokens.index(first)
      finish = tokens.index(last)
      raise PuppetLint::NoFix unless start && finish && start <= finish

      tokens[start..finish]
    end

    def ignored_span?(first, last, check = self.class::NAME)
      ignored = PuppetLint::Data.ignore_overrides.fetch(check, {})
      (first.line..(last.line + last.to_manifest.count("\n"))).any? { |line| ignored.key?(line) }
    end

    def line_prefix(token)
      index = tokens.index(token)
      raise PuppetLint::NoFix unless index

      prefix = +''
      tokens.take(index).reverse_each do |previous|
        text = previous.to_manifest
        prefix.prepend(text.split("\n", -1).last || '')
        break if text.include?("\n")
      end
      prefix
    end

    def whitespace_gap?(left, right)
      token_span(left, right)[1...-1].all? { |token| %i[WHITESPACE INDENT].include?(token.type) }
    end

    def code_after(token)
      index = tokens.index(token)
      raise PuppetLint::NoFix unless index

      tokens.drop(index + 1).find { |following| !PuppetLint::Data.formatting_tokens.include?(following.type) }
    end

    def set_whitespace(left, right, width, type = :WHITESPACE)
      raise PuppetLint::NoFix if width.negative? || !whitespace_gap?(left, right)

      gap = token_span(left, right)[1...-1]
      return insert_whitespace(right, width, type) if gap.empty?

      gap.first.value = ' ' * width
      gap.drop(1).each { |token| remove_token(token) }
    end

    def insert_whitespace(right, width, type)
      return unless width.positive?

      add_token(tokens.index(right), PuppetLint::Lexer::Token.new(type, ' ' * width, right.line, right.column))
    end
  end
end
