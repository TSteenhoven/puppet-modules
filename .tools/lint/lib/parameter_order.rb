# frozen_string_literal: true

module ProjectLint
  # Order defaults topologically while preserving the required/optional alphabetical contract.
  class ParameterOrder
    def initialize(model, parameters)
      @model = model
      @parameters = parameters
      @by_name = parameters.to_h { |parameter| [parameter.name, parameter] }
      @ordered = []
      @visiting = []
    end

    def ordered
      @parameters.sort_by { |parameter| [@model.optional?(parameter) ? 1 : 0, parameter.name] }.each do |parameter|
        visit(parameter)
      end
      @ordered
    end

    def visit(parameter)
      return if @ordered.include?(parameter)
      raise 'Cyclic parameter defaults' if @visiting.include?(parameter)

      @visiting << parameter
      dependencies(parameter).each { |name| visit(@by_name.fetch(name)) }
      @visiting.pop
      @ordered << parameter
    end

    def dependencies(parameter)
      @model.references(parameter.value).select { |name| @by_name.key?(name) }.sort
    end
  end
end
