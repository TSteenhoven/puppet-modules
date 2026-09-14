# frozen_string_literal: true

require_relative 'documentation_blocks'
require_relative 'prose_atoms'

module ProjectLint
  # Share Markdown-aware documentation handling between interface and layout checks.
  module StringsDocumentation
    include DocumentationBlocks

    def control?(text)
      text.match?(/\Alint:(?:ignore|endignore)\b/)
    end

    def structured_prose?(text)
      text.match?(/\A(?:[-*+]\s|\d+[.)]\s|[|>#]|<|\[[^\]]+\]:)/) ||
        text.match?(/!?\[[^\]]*\]\s*(?:\(|\[)/)
    end

    def prose_atoms(text)
      ProseAtoms.new.parse(text)
    end

    def wrap_prose(text, prefix_width)
      return if structured_prose?(text) || text.end_with?('  ', '\\')

      atoms = prose_atoms(text)
      return unless wrappable_atoms?(atoms, prefix_width)

      lines = wrap_atoms(atoms, prefix_width)
      lines unless lines.any? { |line| unsafe_line_start?(line) }
    end

    def wrappable_atoms?(atoms, prefix_width)
      atoms&.none? { |atom| prefix_width + atom.length > 140 }
    end

    def wrap_atoms(atoms, prefix_width)
      lines = []
      atoms.each do |atom|
        if lines.empty? || prefix_width + lines.last.length + 1 + atom.length > 120
          lines << atom.dup
        else
          lines[-1] << ' ' << atom
        end
      end
      lines
    end

    def unsafe_line_start?(line)
      line.start_with?('@') || structured_prose?(line) || line.match?(/\A[-=~]{3,}\z/)
    end

    def literal_example?(text, prefix_width)
      PuppetLint::Lexer.new.tokenise(text).any? do |token|
        %i[SSTRING STRING].include?(token.type) && prefix_width + token.to_manifest.length > 140
      end
    rescue PuppetLint::LexerError
      false
    end
  end
end
