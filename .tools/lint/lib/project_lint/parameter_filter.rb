# frozen_string_literal: true

require 'project_lint/module_resolver'
require 'project_lint/parameter_source'
require 'project_lint/resource_attributes'

module ProjectLint
  # Compare each filtered source value or default with its receiving parameter.
  class ParameterFilter
    include ResourceAttributes

    attr_reader :ast

    def initialize(ast, source)
      @ast = ast
      @source = source
      @resolver = ModuleResolver.new
      @declarations = ast.declarations.to_h { |declaration| [declaration.name, declaration] }
    end

    def redundant_entries(source, filters, parents)
      resource = parents.reverse.find { |parent| parent.is_a?(Ast::M::ResourceExpression) }
      defaults = parameter_defaults(resource, parents)
      return [] unless defaults

      comparisons = filters.map { |filter| comparison(filter) }
      return [] if comparisons.any?(&:nil?)

      source.entries.select { |entry| redundant_entry?(entry, defaults, comparisons) }
    end

    def redundant_entry?(entry, defaults, comparisons)
      target = defaults[@source.literal(entry.key)&.first]
      origin = @source.value(entry.value)
      return false unless origin && target && origin[:value].eql?(target.first)

      !origin[:default] || only_removes_default?(comparisons, origin[:value])
    end

    def only_removes_default?(comparisons, default)
      comparisons.all? { |operator, value| operator == '!=' && value.eql?(default) }
    end

    def parameter_defaults(resource, parents)
      return unless resource && !indirect_attributes?(resource, parents) && !resource_defaults?(resource)

      name = resource.type_name.value
      declaration = @declarations[name] || @resolver.find(name)
      # Class omissions can trigger automatic parameter lookup instead of the declared default.
      return unless declaration.is_a?(Ast::M::ResourceTypeDefinition)

      declaration.parameters.to_h { |parameter| [parameter.name, @source.literal(parameter.value)] }
    end

    def resource_defaults?(resource)
      resource.bodies.any? { |body| body.title.is_a?(Ast::M::LiteralDefault) } ||
        ast.each_node(Ast::M::ResourceDefaultsExpression).any? do |node, _parents|
          node.type_ref.cased_value.downcase == resource.type_name.value
        end
    end

    def comparison(filter)
      test = predicate(filter)
      return unless test.is_a?(Ast::M::ComparisonExpression) && %w[== !=].include?(test.operator)

      value = compared_value(test, filter.lambda.parameters.last.name)
      [test.operator, value.first] if value
    end

    def compared_value(test, name)
      if value_variable?(test.left_expr, name)
        @source.literal(test.right_expr)
      elsif value_variable?(test.right_expr, name)
        @source.literal(test.left_expr)
      end
    end

    def predicate(filter)
      block = filter.lambda
      return unless simple_block?(block)

      body = @source.unwrap(block.body)
      body = body.statements.one? ? body.statements.first : nil if body.is_a?(Ast::M::BlockExpression)
      @source.unwrap(body)
    end

    def simple_block?(block)
      block && block.parameters.length == 2 &&
        block.parameters.none? { |parameter| parameter.type_expr || parameter.value }
    end

    def value_variable?(node, name)
      node = @source.unwrap(node)
      node.is_a?(Ast::M::VariableExpression) && node.expr.value == name
    end
  end
end
