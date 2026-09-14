# frozen_string_literal: true

require_relative '../model'
require_relative '../strings_documentation'

module ProjectLint
  # Check required Strings sections and parameter documentation in declaration order.
  module DocumentationCheck
    include ModelCheck
    include StringsDocumentation

    def check
      documentation_blocks(model.declarations).each do |declaration, rows|
        text = rows.reject { |row| control?(row[:text]) }.map { |row| row[:text] }
        check_sections(declaration, text)
        check_parameters(declaration, text)
        check_descriptions(declaration, text)
      end
    end

    def check_sections(declaration, text)
      issue(declaration, 'Document the declaration with one non-empty @summary') unless text.grep(/^@summary\s+\S/).one?
      unless text.grep(/^@api (?:public|private)$/).one?
        issue(declaration,
              'Document the declaration with @api public or @api private')
      end
      issue(declaration, 'Provide a Puppet Strings @example') if text.grep(/^@example\s+\S/).empty?
    end

    def check_parameters(declaration, text)
      documented = text.filter_map { |line| line[/^@param\s+(?:\[[^\]]+\]\s+)?(\w+)/, 1] }
      return if documented == declaration.parameters.map(&:name)

      issue(declaration, 'Document every parameter exactly once, in declaration order')
    end

    def check_descriptions(declaration, text)
      text.each_with_index do |line, index|
        next unless line.start_with?('@param ')
        next if line.match?(/^@param\s+(?:\[[^\]]+\]\s+)?\w+\s+\S/) || text[index + 1]&.match?(/^\s+\S/)

        issue(declaration, 'Give each @param a description of its contract and default meaning')
      end
    end
  end
end
