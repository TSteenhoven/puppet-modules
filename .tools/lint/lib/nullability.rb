require_relative 'model'

module ProjectLint
  # Prove mutual exclusion only for explicit undef guards and local assignments; unknown expressions remain review findings.
  class Nullability
    M = Model::M

    def initialize(model, resource, parents)
      @model = model
      @resource = resource
      @parents = parents
      @scope = scope(parents)
    end

    def scope(parents)
      parents.reverse.find { |parent| parent.is_a?(M::NamedDefinition) }
    end

    def variable(node)
      node.expr.value if node.is_a?(M::VariableExpression)
    end

    # Conditions use three values: true, false, or nil when the guarded data cannot be proven statically.
    def condition(node, assumptions)
      case node
      when M::ParenthesizedExpression then condition(node.expr, assumptions)
      when M::NotExpression
        value = condition(node.expr, assumptions)
        value.nil? ? nil : !value
      when M::ComparisonExpression
        if node.right_expr.is_a?(M::LiteralUndef) && assumptions.key?(variable(node.left_expr))
          value = assumptions.fetch(variable(node.left_expr))
          return node.operator == '==' ? value : !value if %w[== !=].include?(node.operator)
        end
        nil
      when M::AndExpression
        left = condition(node.left_expr, assumptions)
        right = condition(node.right_expr, assumptions)
        return false if left == false || right == false
        left == true && right == true ? true : nil
      when M::OrExpression
        left = condition(node.left_expr, assumptions)
        right = condition(node.right_expr, assumptions)
        return true if left == true || right == true
        left == false && right == false ? false : nil
      else nil
      end
    end

    def reachable?(node, parents, assumptions)
      path = parents + [node]
      parents.each_with_index do |parent, index|
        next unless parent.is_a?(M::IfExpression)
        value = condition(parent.test, assumptions)
        child = path[index + 1]
        return false if (child.equal?(parent.then_expr) && value == false) || (child.equal?(parent.else_expr) && value == true)
      end
      true
    end

    def always_null?(node, assumptions, seen = [])
      return true if node.is_a?(M::LiteralUndef)
      name = variable(node)
      return false unless name
      return assumptions[name] if assumptions.key?(name)
      return false if seen.include?(name)

      assignments = @model.nodes.select do |candidate, parents|
        candidate.is_a?(M::AssignmentExpression) && variable(candidate.left_expr) == name && scope(parents).equal?(@scope) &&
          candidate.offset < @resource.offset && reachable?(candidate, parents, assumptions)
      end
      !assignments.empty? && assignments.all? { |candidate, _| always_null?(candidate.right_expr, assumptions, seen + [name]) }
    end

    def exclusive?(source, content)
      names = [variable(source), variable(content)].compact
      nonnull = names.to_h { |name| [name, false] }
      return true unless reachable?(@resource, @parents, nonnull)
      return true if variable(source) && always_null?(content, { variable(source) => false })
      return true if variable(content) && always_null?(source, { variable(content) => false })

      false
    end
  end
end
