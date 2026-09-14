# frozen_string_literal: true

require_relative '../model'
require_relative '../token_helpers'
require_relative '../layout/array_indentation'
require_relative '../layout/brace_spacing'
require_relative '../layout/fixes'

module ProjectLint
  # Coordinate array, brace and comma layout checks using original source positions.
  module LayoutCheck
    include ModelCheck
    include TokenHelpers
    include Layout::ArrayIndentation
    include Layout::BraceSpacing
    include Layout::Fixes

    def report_edit(message, line, column, edit)
      @edits << edit
      notify(:warning, message: message, line: line, column: column, edit: @edits.length - 1)
    end

    def check
      @edits = []
      @positions = tokens.to_h { |token| [[token.line, token.column], token] }
      check_array_indentation
      check_opening_brace_spacing
      check_commas
      (class_indexes + defined_type_indexes).each { |declaration| check_parameter_comma(declaration) }
    end

    def check_commas
      tokens.each { |token| check_comma_gap(token) if token.type == :COMMA && token.next_code_token }
    end

    def check_comma_gap(token)
      following = token.next_code_token
      return if following.line != token.line || %i[RBRACK RBRACE RPAREN].include?(following.type)
      return if token.next_token.type == :WHITESPACE && token.next_token.value == ' '

      report_edit('Use one space after a same-line comma', token.line, token.column, comma: token, following: following)
    end

    def multiline_parameter_end(declaration, parameters)
      code = parameters.reject { |token| PuppetLint::Data.formatting_tokens.include?(token.type) }
      last = code.last
      last if last && declaration[:name_token].line != last.line && last.type != :COMMA
    end

    def check_parameter_comma(declaration)
      parameters = declaration[:param_tokens]
      return unless parameters&.any?

      last = multiline_parameter_end(declaration, parameters)
      return unless last

      report_edit('End a multiline parameter block with a trailing comma', last.line, last.column,
                  closing: parameters.last.next_token)
    end
  end
end
