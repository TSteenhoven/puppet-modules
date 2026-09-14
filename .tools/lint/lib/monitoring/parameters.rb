# frozen_string_literal: true

require_relative 'value'

module ProjectLint
  module Monitoring
    # Identify parameters forwarded as backend settings, including local aliases.
    module Parameters
      def scoped_nodes(declaration)
        model.nodes.filter_map do |node, parents|
          next unless parents.include?(declaration)

          bound = parents.grep(M::LambdaExpression).flat_map do |lambda|
            lambda.parameters.map(&:name) + local_names(lambda.body)
          end
          [node, bound]
        end
      end

      def backend_parameters(declaration)
        nodes = scoped_nodes(declaration)
        names = nodes.flat_map { |resource, bound| forwarded_names(resource, bound) }
        names = resolve_aliases(nodes, names)
        declaration.parameters.map(&:name) & names
      end

      def forwarded_names(resource, bound)
        return [] unless resource.is_a?(M::ResourceExpression)
        return [] unless resource_names(resource).any? { |name| wrapper?(name) }

        resource.bodies.flat_map do |body|
          package_attributes(body).flat_map { |operation| variable_reads(operation.value_expr) - bound }
        end
      end

      def package_attributes(body)
        body.operations.select do |operation|
          operation.is_a?(M::AttributeOperation) && operation.attribute_name == 'package'
        end
      end

      def resolve_aliases(nodes, names)
        loop do
          previous = names.uniq
          nodes.each do |assignment, bound|
            next if ((assignment_names(assignment) - bound) & names).empty?

            names |= (variable_reads(assignment.right_expr) - bound)
          end
          return names if previous == names.uniq
        end
      end
    end
  end
end
