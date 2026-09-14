module ProjectLint
  # Share documentation boundaries between interface validation and the formatting plugin.
  # Only lexer comments belong to documentation; hash-prefixed lines in strings/heredocs do not.
  module StringsDocumentation
    def control?(text)
      text.match?(/\Alint:(?:ignore|endignore)\b/)
    end

    def documentation_blocks(declarations)
      comments = tokens.select do |token|
        token.type == :COMMENT && manifest_lines[token.line - 1][0, token.column - 1].strip.empty?
      end.to_h { |token| [token.line, token] }
      declarations.map do |declaration|
        line = declaration.line - 1
        rows = []
        while line.positive? && (comments[line] || manifest_lines[line - 1].strip.empty?)
          source = manifest_lines[line - 1]
          token = comments[line]
          rows.unshift(line: line, token: token, indent: source[/\A[ \t]*/],
                       text: token ? token.value.delete_prefix(' ') : '')
          line -= 1
        end
        rows.shift while rows.any? && !rows.first[:token]
        # Blank lines before the declaration are outside the docstring; the interface check reports missing docs.
        rows = [] if rows.any? && !rows.last[:token]
        [declaration, rows]
      end
    end

    def structured_prose?(text)
      text.match?(/\A(?:[-*+]\s|\d+[.)]\s|[|>#]|<|\[[^\]]+\]:)/) ||
        text.match?(/!?\[[^\]]*\]\s*(?:\(|\[)/)
    end

    # Backtick spans are indivisible, including their internal whitespace and delimiter spelling.
    # Refuse unmatched/escaped delimiters and tabs instead of guessing at Markdown semantics.
    def prose_atoms(text)
      return nil if text.include?("\t") || text.include?('\\`')

      atoms = []
      atom = +''
      delimiter = nil
      text.scan(/`+|[^`\s]+|\s+/).each do |part|
        if part.start_with?('`')
          delimiter = delimiter ? (part == delimiter ? nil : delimiter) : part
          atom << part
        elsif part.match?(/\A\s+\z/) && !delimiter
          atoms << atom unless atom.empty?
          atom = +''
        else
          atom << part
        end
      end
      return nil if delimiter

      atoms << atom unless atom.empty?
      atoms
    end

    def wrap_prose(text, prefix_width)
      return nil if structured_prose?(text) || text.end_with?('  ', '\\')

      atoms = prose_atoms(text)
      return nil unless atoms && atoms.none? { |atom| prefix_width + atom.length > 140 }

      lines = []
      atoms.each do |atom|
        if lines.empty? || prefix_width + lines.last.length + 1 + atom.length > 120
          lines << atom.dup
        else
          lines[-1] << ' ' << atom
        end
      end
      # A new physical line must not turn a word into a YARD tag, list, heading, or Markdown rule.
      return nil if lines.any? { |line| line.start_with?('@') || structured_prose?(line) || line.match?(/\A[-=~]{3,}\z/) }

      lines
    end

    def literal_example?(text, prefix_width)
      PuppetLint::Lexer.new.tokenise(text).any? do |token|
        [:SSTRING, :STRING].include?(token.type) && prefix_width + token.to_manifest.length > 140
      end
    rescue PuppetLint::LexerError
      false
    end
  end
end
