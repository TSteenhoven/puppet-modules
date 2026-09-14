# frozen_string_literal: true

module ProjectLint
  # Capture parameter token anchors once so other native fixes can update their widths.
  class ParameterBlocks
    def initialize(model, source_tokens)
      @model = model
      @positions = source_tokens.to_h { |token| [[token.line, token.column], token] }
    end

    def blocks
      @model.declarations.filter_map do |declaration|
        parameters = declaration.parameters
        next if parameters.empty? || parameters.any? { |parameter| parameter.type_expr.nil? }

        parameters.map { |parameter| entry(parameter) }
      end
    end

    def entry(parameter)
      variable = @positions.fetch([parameter.line, parameter.pos])
      type = parameter.type_expr
      { variable: variable, type_start: @positions.fetch([type.line, type.pos]),
        type_end: variable.prev_code_token, equals: parameter.value ? variable.next_code_token : nil }
    end
  end
end
