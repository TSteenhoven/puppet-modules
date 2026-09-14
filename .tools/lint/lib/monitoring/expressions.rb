# frozen_string_literal: true

require_relative 'value'

module ProjectLint
  module Monitoring
    # Propagate backend provenance through resources and remaining expressions.
    module Expressions
      def combine(values)
        Value.new(values.any?(&:backend), nil, values.flat_map(&:decisions).uniq)
      end

      def evaluate_literal(node, *)
        Value.new(false, node.value, [])
      end

      def evaluate_parentheses(node, environment, guards, owner)
        evaluate(node.expr, environment, guards, owner)
      end

      def evaluate_block(node, environment, guards, owner)
        node.statements.reduce(Value.new(false, nil, [])) do |_previous, statement|
          evaluate(statement, environment, guards, owner)
        end
      end

      def evaluate_resource(node, environment, guards, owner)
        values = node.bodies.flat_map do |body|
          [body.title, *body.operations].map { |part| evaluate(part, environment, guards, owner) }
        end
        @warnings |= guards + values.flat_map(&:decisions) if calls_wrapper?(owner, resource_names(node))
        combine(values)
      end

      def calls_wrapper?(owner, names)
        owner != TARGET && names.any? { |name| wrapper?(name) }
      end

      def evaluate_children(node, environment, guards, owner)
        values = node.enum_for(:_pcore_contents).map { |child| evaluate(child, environment, guards, owner) }
        result = combine(values)
        @warnings |= guards + result.decisions if calls_wrapper?(owner, included_names(node))
        inspect_binary(node, result, values) if node.is_a?(M::BinaryExpression) && result.backend
        result
      end

      def allowed_comparison?(node, values)
        node.is_a?(M::ComparisonExpression) && %w[== !=].include?(node.operator) &&
          values.any? { |value| value.literal == 'none' }
      end

      def inspect_binary(node, result, values)
        # Boolean composition preserves unresolved reads until they reach a decision.
        return if node.is_a?(M::AndExpression) || node.is_a?(M::OrExpression)

        result.decisions << node unless allowed_comparison?(node, values)
        result.backend = false
      end
    end
  end
end
