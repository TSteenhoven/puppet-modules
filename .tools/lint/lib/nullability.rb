# frozen_string_literal: true

require_relative 'model'
require_relative 'null_condition'

module ProjectLint
  # Prove exclusion only for explicit undef guards and reachable local assignments.
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

    def condition(node, assumptions)
      NullCondition.new(assumptions).evaluate(node)
    end

    def unreachable_branch?(parent, child, assumptions)
      return false unless parent.is_a?(M::IfExpression)

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
      @model.each_node(M::AssignmentExpression).select do |candidate, parents|
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
      return true if node.is_a?(M::LiteralUndef)

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
  end
end
