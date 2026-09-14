# frozen_string_literal: true

module ProjectLint
  # Tokenize prose while preserving complete backtick spans and internal whitespace.
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
end
