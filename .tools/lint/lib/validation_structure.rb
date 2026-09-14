# frozen_string_literal: true

require_relative 'validation_guard'

module ProjectLint
  # Report each invalid guard once and retain terminal fallbacks for branch-size comparison.
  class ValidationStructure
    def initialize(check)
      @check = check
      @reported = []
      @terminal = []
    end

    def guards
      @check.model.each_node do |node, parents|
        inspect_diagnostic(node, parents) if @check.diagnostic?(node)
      end
      @reported | @terminal
    end

    def inspect_diagnostic(node, parents)
      context = ValidationGuard.new(@check, node, parents)
      return unless context.eligible?
      return if @reported.include?(context.guard)

      message = guard_message(context)
      if message
        @check.issue(context.guard, message)
        @reported << context.guard
      else
        @terminal << context.guard
      end
    end

    def guard_message(context)
      if !context.valid_branch?
        'Put validation warning() and fail() calls in the final else (or case default), ' \
          'with regular implementation in the valid branch'
      elsif context.implementation_follows?
        'Keep the remaining implementation inside the valid branch; no implementation may follow this validation ' \
          'or its enclosing blocks within the class or defined type'
      end
    end
  end
end
