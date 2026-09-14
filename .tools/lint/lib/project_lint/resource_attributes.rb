# frozen_string_literal: true

require 'project_lint/ast'

module ProjectLint
  # Resolve local resource defaults and retain review requirements for catalog-only attributes.
  module ResourceAttributes
    include AstCheck

    def literal(node)
      case node
      when Ast::M::LiteralString, Ast::M::LiteralBoolean, Ast::M::LiteralInteger, Ast::M::QualifiedName then node.value
      when Ast::M::LiteralList then node.values.map { |value| literal(value) }
      end
    end

    def apt_options?(node)
      required = ['--no-install-recommends', '--no-install-suggests']
      values = literal(node)
      return (required - values.last(2)).empty? if values.is_a?(Array)
      return false unless node.is_a?(Ast::M::CallNamedFunctionExpression) && node.functor_expr.value == 'concat'

      # Concat retains trailing duplicates, so caller flags cannot move the final policy earlier.
      apt_options?(node.arguments.last)
    end

    def attribute_values(operations)
      operations.grep(Ast::M::AttributeOperation).to_h { |operation| [operation.attribute_name, operation.value_expr] }
    end

    def visible_defaults?(node, resource, parents, ancestors)
      node.type_ref.cased_value.downcase == resource.type_name.value &&
        node.offset < resource.offset && parents.all? { |parent| ancestors.include?(parent) }
    end

    def attributes(resource, body, ancestors)
      values = {}
      ast.each_node(Ast::M::ResourceDefaultsExpression) do |node, parents|
        values.merge!(attribute_values(node.operations)) if visible_defaults?(node, resource, parents, ancestors)
      end
      values.merge(attribute_values(body.operations))
    end

    def inherited_attributes?(parents)
      parents.any? { |parent| parent.is_a?(Ast::M::HostClassDefinition) && parent.parent_class }
    end

    def override_for?(node, resource)
      reference = node.resources
      reference.is_a?(Ast::M::AccessExpression) && reference.left_expr.is_a?(Ast::M::QualifiedReference) &&
        reference.left_expr.cased_value.downcase == resource.type_name.value
    end

    def indirect_attributes?(resource, parents)
      inherited_attributes?(parents) || ast.each_node(Ast::M::ResourceOverrideExpression).any? do |node, _ancestors|
        override_for?(node, resource)
      end
    end
  end
end
