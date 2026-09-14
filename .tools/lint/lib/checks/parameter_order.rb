# frozen_string_literal: true

require_relative '../model'

module ProjectLint
  # Check declaration order and explain necessary deviations from alphabetical order.
  module ParameterOrderCheck
    include ModelCheck

    def check
      model.declarations.each do |declaration|
        expected = model.parameter_order(declaration)
        check_order(declaration, expected)
        check_forward_references(declaration.parameters)
        check_dependency_comments(declaration.parameters, expected)
      end
    end

    def check_order(declaration, expected)
      return if declaration.parameters == expected

      issue(declaration, 'Put mandatory parameters first, then optional parameters; sort each group alphabetically ' \
                         'subject to local default dependencies')
    end

    def check_forward_references(parameters)
      positions = parameters.each_with_index.to_h { |parameter, index| [parameter.name, index] }
      parameters.each do |parameter|
        # Report each forward dependency separately.
        forward_dependencies(parameter, positions).each do |_dependency|
          issue(parameter, 'A local default refers to a parameter that must be declared earlier')
        end
      end
    end

    def forward_dependencies(parameter, positions)
      model.references(parameter.value).select do |dependency|
        positions.key?(dependency) && positions[dependency] >= positions.fetch(parameter.name)
      end
    end

    def check_dependency_comments(parameters, expected)
      ordinary = parameters.sort_by { |parameter| [model.optional?(parameter) ? 1 : 0, parameter.name] }
      expected.each do |parameter|
        next unless expected.index(parameter) < ordinary.index(parameter)

        dependents = default_dependents(parameters, parameter)
        check_comment(parameter, dependents) unless dependents.empty?
      end
    end

    def default_dependents(parameters, parameter)
      parameters.select { |other| model.references(other.value).include?(parameter.name) }
    end

    def check_comment(parameter, dependents)
      comments = tokens.select { |token| token.type == :COMMENT && token.line == parameter.line }
      return if comments.any? { |comment| dependents.any? { |dependent| comment.value.include?("$#{dependent.name}") } }

      issue(parameter, 'Explain the necessary default dependency in a trailing comment naming the dependent parameter')
    end
  end
end
