# frozen_string_literal: true

require_relative 'model'

module ProjectLint
  # Resolve local resource defaults and retain review requirements for catalog-only attributes.
  module ResourceCheck
    include ModelCheck

    M = Model::M

    def literal(node)
      case node
      when M::LiteralString, M::LiteralBoolean, M::LiteralInteger, M::QualifiedName then node.value
      when M::LiteralList then node.values.map { |value| literal(value) }
      end
    end

    def apt_options?(node)
      required = ['--no-install-recommends', '--no-install-suggests']
      values = literal(node)
      return (required - values.last(2)).empty? if values.is_a?(Array)
      return false unless node.is_a?(M::CallNamedFunctionExpression) && node.functor_expr.value == 'concat'

      # Concat retains trailing duplicates, so caller flags cannot move the final policy earlier.
      apt_options?(node.arguments.last)
    end

    def attribute_values(operations)
      operations.grep(M::AttributeOperation).to_h { |operation| [operation.attribute_name, operation.value_expr] }
    end

    def visible_defaults?(node, resource, parents, ancestors)
      node.type_ref.cased_value.downcase == resource.type_name.value &&
        node.offset < resource.offset && parents.all? { |parent| ancestors.include?(parent) }
    end

    def attributes(resource, body, ancestors)
      values = {}
      model.each_node(M::ResourceDefaultsExpression) do |node, parents|
        values.merge!(attribute_values(node.operations)) if visible_defaults?(node, resource, parents, ancestors)
      end
      values.merge(attribute_values(body.operations))
    end

    def inherited_attributes?(parents)
      parents.any? { |parent| parent.is_a?(M::HostClassDefinition) && parent.parent_class }
    end

    def override_for?(node, resource)
      reference = node.resources
      reference.is_a?(M::AccessExpression) && reference.left_expr.is_a?(M::QualifiedReference) &&
        reference.left_expr.cased_value.downcase == resource.type_name.value
    end

    def indirect_attributes?(resource, parents)
      inherited_attributes?(parents) || model.each_node(M::ResourceOverrideExpression).any? do |node, _ancestors|
        override_for?(node, resource)
      end
    end
  end
end
