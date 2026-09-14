# frozen_string_literal: true

require_relative '../section_layout'
require_relative '../token_helpers'

module ProjectLint
  # Insert separators at explanatory comment boundaries without moving comments.
  module CommentSpacingCheck
    include SectionLayout
    include TokenHelpers

    def check
      @boundaries = comment_sections.select { |section| missing_separator?(section.first) }
      @boundaries.each_with_index do |section, index|
        first = section.first
        notify(:warning, message: 'Put a blank line before a standalone explanatory comment block',
                         line: first.line, column: first.column, edit: index)
      end
    end

    def missing_separator?(first)
      previous = adjacent_code(first, :prev_token)
      previous && !%i[LBRACE LBRACK LPAREN].include?(previous.type) &&
        !PuppetLint::Data.manifest_lines[first.line - 2].strip.empty?
    end

    def fix(problem)
      section = @boundaries.fetch(problem[:edit])
      raise PuppetLint::NoFix if ignored_span?(section.first, section.last)

      first = section.find { |token| tokens.include?(token) }
      newline = separator_anchor(first)
      return unless newline

      add_token(tokens.index(newline) + 1, PuppetLint::Lexer::Token.new(:NEWLINE, "\n", first.line, 1))
    end

    def remove_horizontal_space(preceding)
      preceding.pop while preceding.last && %i[INDENT WHITESPACE].include?(preceding.last.type)
    end

    def separator_anchor(first)
      index = tokens.index(first)
      raise PuppetLint::NoFix unless index

      preceding = tokens.take(index)
      remove_horizontal_space(preceding)
      newline = preceding.pop
      raise PuppetLint::NoFix unless newline&.type == :NEWLINE

      remove_horizontal_space(preceding)
      newline unless preceding.last&.type == :NEWLINE
    end
  end
end
