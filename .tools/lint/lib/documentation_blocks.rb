# frozen_string_literal: true

module ProjectLint
  # Locate contiguous documentation using lexer comments rather than hash-prefixed data.
  module DocumentationBlocks
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
  end
end
