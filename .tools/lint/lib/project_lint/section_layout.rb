# frozen_string_literal: true

require 'project_lint/ast'

module ProjectLint
  # Find comment sections using lexer positions, preserving actual literal contents.
  module SectionLayout
    include AstCheck

    def control_comment?(token)
      token.value.strip.match?(/\Alint:(?:ignore|endignore)\b/)
    end

    def comment_end_line(token)
      token.line + token.value.count("\n")
    end

    # Native code links omit comments; walk full links at section boundaries.
    def adjacent_code(token, direction)
      token = token.public_send(direction)
      token = token.public_send(direction) while token && PuppetLint::Data.formatting_tokens.include?(token.type)
      token
    end

    def standalone_comment?(token)
      return false unless %i[COMMENT MLCOMMENT SLASH_COMMENT].include?(token.type)
      return false unless PuppetLint::Data.manifest_lines[token.line - 1][0, token.column - 1].strip.empty?

      following = adjacent_code(token, :next_token)
      !following || following.line > comment_end_line(token)
    end

    def grouped_comments
      sections = []
      tokens.select { |token| standalone_comment?(token) }.each do |token|
        if sections.last && comment_end_line(sections.last.last) + 1 >= token.line
          sections.last << token
        else
          sections << [token]
        end
      end
      sections
    end

    def comment_sections
      grouped_comments.filter_map do |section|
        # A closing suppression belongs to preceding code.
        section = section.drop_while { |token| token.value.strip == 'lint:endignore' }
        section if section.any? { |token| !control_comment?(token) && !token.value.strip.empty? }
      end
    end

    def token_positions
      tokens.to_h { |token| [[token.line, token.column], token] }
    end

    def section_starts
      comment_sections.filter_map do |section|
        following = adjacent_code(section.last, :next_token)
        next unless following && following.line == comment_end_line(section.last) + 1

        [[following.line, following.column], section.first.line]
      end.to_h
    end
  end
end
