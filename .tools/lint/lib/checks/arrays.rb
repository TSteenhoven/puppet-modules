# frozen_string_literal: true

require_relative '../model'

module ProjectLint
  # Recognize array addition from local assignments and declared parameter types.
  module ArraysCheck
    include ModelCheck

    def array?(node, scope, seen = [])
      return true if node.is_a?(Model::M::LiteralList)
      return false unless node.is_a?(Model::M::VariableExpression)

      name = node.expr.value
      return false if seen.include?(name)

      array_source?(name, scope, seen)
    end

    def array_source?(name, scope, seen)
      model.nodes.any? do |candidate, parents|
        next false unless model.scope_of(parents).equal?(scope)

        array_parameter?(candidate, name) || array_assignment?(candidate, name, scope, seen)
      end
    end

    def array_parameter?(candidate, name)
      candidate.is_a?(Model::M::Parameter) && candidate.name == name &&
        model.named_type?(candidate.type_expr, 'Array')
    end

    def array_assignment?(candidate, name, scope, seen)
      return false unless candidate.is_a?(Model::M::AssignmentExpression)

      left = candidate.left_expr
      left.is_a?(Model::M::VariableExpression) && left.expr.value == name &&
        array?(candidate.right_expr, scope, seen + [name])
    end

    def check
      model.each_node(Model::M::ArithmeticExpression) do |node, parents|
        next unless node.operator == '+'

        scope = model.scope_of(parents)
        next unless array?(node.left_expr, scope) || array?(node.right_expr, scope)

        issue(node, 'Combine arrays with concat(...) while preserving element order')
      end
    end
  end
end
