# frozen_string_literal: true

module ProjectLint
  module References
    # Limit reorder/unwrap fixes to consumers that flatten relationship arrays.
    module Context
      M = Model::M
      CONTAINERS = [M::Program, M::BlockExpression, M::HostClassDefinition, M::ResourceTypeDefinition,
                    M::NodeDefinition, M::IfExpression, M::RelationshipExpression, M::ParenthesizedExpression].freeze

      def relationship_context?(node, parents)
        child = node
        parents.reverse_each do |parent|
          return consuming_context?(parent, child, parents) unless array_container?(parent)

          child = parent
        end
        false
      end

      def array_container?(node)
        node.is_a?(M::LiteralList) || node.is_a?(M::ParenthesizedExpression)
      end

      def consuming_context?(parent, child, parents)
        return safe_relationship?(parent, parents) if parent.is_a?(M::RelationshipExpression)

        parent.is_a?(M::AttributeOperation) && parent.value_expr.equal?(child) &&
          %w[require before notify subscribe].include?(parent.attribute_name)
      end

      def safe_relationship?(parent, parents)
        parents.take(parents.index(parent)).all? { |ancestor| CONTAINERS.any? { |type| ancestor.is_a?(type) } }
      end

      def reference?(node)
        return false unless node.is_a?(M::AccessExpression) && node.left_expr.is_a?(M::QualifiedReference)

        name = node.left_expr.value
        return false if name != 'class' && Puppet::Pops::Types::TypeParser.type_map.key?(name)

        !@type_names.include?(name)
      end

      def literal_title?(node)
        node.is_a?(M::LiteralString) || node.is_a?(M::QualifiedName)
      end

      def literal_reference?(node)
        reference?(node) && node.keys.all? { |title| literal_title?(title) }
      end
    end
  end
end
