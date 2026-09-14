# frozen_string_literal: true

require 'project_lint/ast'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Check declaration order and explain necessary deviations from alphabetical order.
    module ParameterOrder
      # Order parameter defaults by their local dependency graph.
      class ParameterDependencies
        def initialize(ast, parameters)
          @ast = ast
          @parameters = parameters
          @by_name = parameters.to_h { |parameter| [parameter.name, parameter] }
          @ordered = []
          @visiting = []
        end

        def ordered
          @parameters.sort_by { |parameter| [@ast.optional?(parameter) ? 1 : 0, parameter.name] }.each do |parameter|
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
          @ast.references(parameter.value).select { |name| @by_name.key?(name) }.sort
        end
      end

      include AstCheck

      def check
        ast.declarations.each do |declaration|
          expected = ParameterDependencies.new(ast, declaration.parameters).ordered
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
        ast.references(parameter.value).select do |dependency|
          positions.key?(dependency) && positions[dependency] >= positions.fetch(parameter.name)
        end
      end

      def check_dependency_comments(parameters, expected)
        ordinary = parameters.sort_by { |parameter| [ast.optional?(parameter) ? 1 : 0, parameter.name] }
        expected.each do |parameter|
          next unless expected.index(parameter) < ordinary.index(parameter)

          dependents = default_dependents(parameters, parameter)
          check_comment(parameter, dependents) unless dependents.empty?
        end
      end

      def default_dependents(parameters, parameter)
        parameters.select { |other| ast.references(other.value).include?(parameter.name) }
      end

      def check_comment(parameter, dependents)
        comments = tokens.select { |token| token.type == :COMMENT && token.line == parameter.line }
        return if comments.any? do |comment|
          dependents.any? do |dependent|
            comment.value.include?("$#{dependent.name}")
          end
        end

        issue(parameter,
              'Explain the necessary default dependency in a trailing comment naming the dependent parameter')
      end
    end
    PuppetLint.new_check(:project_parameter_order) { include ParameterOrder }
  end
end
