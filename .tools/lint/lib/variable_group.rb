# frozen_string_literal: true

module ProjectLint
  # Keep dependency state within one annotated statement block.
  class VariableGroup
    def initialize(check, starts)
      @check = check
      @starts = starts
      @annotated = false
      reset
    end

    def reset
      @linked = false
      @assigned = []
    end

    def inspect_assignment(node)
      names = @check.assignment_names(node)
      if names.empty?
        @annotated = false
        return
      end
      start(node)
      inspect_dependency(node, names) if @annotated
    end

    def start(node)
      return unless @starts.key?([node.left_expr.line, node.left_expr.pos])

      @annotated = true
      reset
    end

    def inspect_dependency(node, names)
      related = (@check.variable_reads(node.right_expr) & @assigned).any?
      if @linked && !related
        @check.issue(node.left_expr, 'Start unrelated assignments after a dependent variable group with a blank line ' \
                                     'and a new explanatory comment')
        reset
      end
      @linked ||= related
      @assigned.concat(names)
    end
  end
end
