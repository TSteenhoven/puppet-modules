# frozen_string_literal: true

module ProjectLint
  # Walk only adjacent assignments that feed an if/elsif condition.
  class ConditionPreparation
    M = Model::M

    def initialize(check, positions)
      @check = check
      @positions = positions
    end

    def start(node, parents)
      anchor, parent = assignment_anchor(node, parents)
      target = parent.is_a?(M::BlockExpression) ? dependency_start(node, anchor, parent) : anchor
      target.is_a?(M::AssignmentExpression) ? target.left_expr : target
    end

    def assignment_anchor(node, parents)
      parent = parents.last
      if parent.is_a?(M::AssignmentExpression) && parent.right_expr.equal?(node)
        [parent, parents[-2]]
      else
        [node, parent]
      end
    end

    def condition_reads(node)
      needed = @check.variable_reads(node.test)
      following = node.else_expr
      while elsif?(following)
        needed |= @check.variable_reads(following.test)
        following = following.else_expr
      end
      needed
    end

    def elsif?(node)
      node.is_a?(M::IfExpression) && @positions.fetch([node.line, node.pos]).type == :ELSIF
    end

    def dependency_start(node, anchor, parent)
      needed = condition_reads(node)
      target = anchor
      parent.statements.take(parent.statements.index(anchor)).reverse_each do |previous|
        names = @check.assignment_names(previous)
        break if (names & needed).empty?

        target = previous
        needed = (needed - names) | @check.variable_reads(previous.right_expr)
      end
      target
    end
  end
end
