# frozen_string_literal: true

module ProjectLint
  # Evaluate explicit undef conditions using true, false and unknown (nil).
  class NullCondition
    M = Model::M

    def initialize(assumptions)
      @assumptions = assumptions
    end

    def evaluate(node)
      case node
      when M::ParenthesizedExpression then evaluate(node.expr)
      when M::NotExpression then negate(evaluate(node.expr))
      when M::ComparisonExpression then compare(node)
      when M::AndExpression then conjunction(evaluate(node.left_expr), evaluate(node.right_expr))
      when M::OrExpression then disjunction(evaluate(node.left_expr), evaluate(node.right_expr))
      end
    end

    def negate(value)
      !value unless value.nil?
    end

    def compare(node)
      left = node.left_expr
      return unless node.right_expr.is_a?(M::LiteralUndef) && left.is_a?(M::VariableExpression)
      return unless @assumptions.key?(left.expr.value)

      value = @assumptions.fetch(left.expr.value)
      return value if node.operator == '=='

      !value if node.operator == '!='
    end

    def conjunction(left, right)
      return false if left == false || right == false

      true if left == true && right == true
    end

    def disjunction(left, right)
      return true if left == true || right == true

      false if left == false && right == false
    end
  end
end
