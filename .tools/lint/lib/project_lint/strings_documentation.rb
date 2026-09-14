# frozen_string_literal: true

module ProjectLint
  # Share Markdown-aware documentation handling between interface and layout checks.
  module StringsDocumentation
    # Split prose without breaking markup or literal values.
    class ProseAtoms
      def initialize
        @atoms = []
        @atom = +''
        @delimiter = nil
      end

      def parse(text)
        return if text.include?("\t") || text.include?('\\`')

        text.scan(/`+|[^`\s]+|\s+/).each { |part| append(part) }
        return if @delimiter

        finish_atom
        @atoms
      end

      def finish_atom
        @atoms << @atom unless @atom.empty?
        @atom = +''
      end

      def append(part)
        if part.start_with?('`')
          @delimiter = next_delimiter(part)
          @atom << part
        elsif part.match?(/\A\s+\z/) && !@delimiter
          finish_atom
        else
          @atom << part
        end
      end

      def next_delimiter(part)
        return part unless @delimiter

        part == @delimiter ? nil : @delimiter
      end
    end

    def documentation_comments
      comments = tokens.select do |token|
        token.type == :COMMENT && manifest_lines[token.line - 1][0, token.column - 1].strip.empty?
      end
      comments.to_h { |token| [token.line, token] }
    end

    def documentation_blocks(declarations)
      comments = documentation_comments
      declarations.map { |declaration| [declaration, rows_before(declaration, comments)] }
    end

    def documentation_row(line, token)
      source = manifest_lines[line - 1]
      { line: line, token: token, indent: source[/\A[ \t]*/], text: token ? token.value.delete_prefix(' ') : '' }
    end

    def trim_documentation_rows(rows)
      rows.shift while rows.any? && !rows.first[:token]
      # A blank source line before the declaration ends its docstring.
      rows.any? && !rows.last[:token] ? [] : rows
    end

    def rows_before(declaration, comments)
      line = declaration.line - 1
      rows = []
      while line.positive? && (comments[line] || manifest_lines[line - 1].strip.empty?)
        rows.unshift(documentation_row(line, comments[line]))
        line -= 1
      end
      trim_documentation_rows(rows)
    end

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
