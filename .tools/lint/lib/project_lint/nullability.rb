# frozen_string_literal: true

require 'project_lint/ast'

module ProjectLint
  # Prove exclusion only for explicit undef guards and reachable local assignments.
  class Nullability
    def initialize(ast, resource, parents)
      @ast = ast
      @resource = resource
      @parents = parents
      @scope = scope(parents)
    end

    def scope(parents)
      parents.reverse.find { |parent| parent.is_a?(Ast::M::NamedDefinition) }
    end

    def variable(node)
      node.expr.value if node.is_a?(Ast::M::VariableExpression)
    end

    def unreachable_branch?(parent, child, assumptions)
      return false unless parent.is_a?(Ast::M::IfExpression)

      value = condition(parent.test, assumptions)
      (child.equal?(parent.then_expr) && value == false) || (child.equal?(parent.else_expr) && value == true)
    end

    def reachable?(node, parents, assumptions)
      path = parents + [node]
      parents.each_with_index.none? do |parent, index|
        unreachable_branch?(parent, path[index + 1], assumptions)
      end
    end

    def matching_assignment?(candidate, parents, name, assumptions)
      variable(candidate.left_expr) == name && scope(parents).equal?(@scope) &&
        candidate.offset < @resource.offset && reachable?(candidate, parents, assumptions)
    end

    def assignments(name, assumptions)
      @ast.each_node(Ast::M::AssignmentExpression).select do |candidate, parents|
        matching_assignment?(candidate, parents, name, assumptions)
      end
    end

    def null_assignments?(name, assumptions, seen)
      candidates = assignments(name, assumptions)
      !candidates.empty? && candidates.all? do |candidate, _parents|
        always_null?(candidate.right_expr, assumptions, seen + [name])
      end
    end

    def always_null?(node, assumptions, seen = [])
      return true if node.is_a?(Ast::M::LiteralUndef)

      name = variable(node)
      return false unless name
      return assumptions[name] if assumptions.key?(name)
      return false if seen.include?(name)

      null_assignments?(name, assumptions, seen)
    end

    def exclusive?(source, content)
      names = [variable(source), variable(content)].compact
      nonnull = names.to_h { |name| [name, false] }
      !reachable?(@resource, @parents, nonnull) || excludes?(source, content) || excludes?(content, source)
    end

    def excludes?(source, content)
      name = variable(source)
      return false unless name

      always_null?(content, { name => false })
    end

    def condition(node, assumptions)
      case node
      when Ast::M::ParenthesizedExpression then condition(node.expr, assumptions)
      when Ast::M::NotExpression then negate(condition(node.expr, assumptions))
      when Ast::M::ComparisonExpression then compare(node, assumptions)
      when Ast::M::AndExpression then conjunction(condition(node.left_expr, assumptions),
                                                  condition(node.right_expr, assumptions))
      when Ast::M::OrExpression then disjunction(condition(node.left_expr, assumptions),
                                                 condition(node.right_expr, assumptions))
      end
    end

    def negate(value)
      !value unless value.nil?
    end

    def compare(node, assumptions)
      left = node.left_expr
      return unless node.right_expr.is_a?(Ast::M::LiteralUndef) && left.is_a?(Ast::M::VariableExpression)
      return unless assumptions.key?(left.expr.value)

      value = assumptions.fetch(left.expr.value)
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
