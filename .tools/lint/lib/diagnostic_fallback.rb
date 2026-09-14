# frozen_string_literal: true

module ProjectLint
  # Accept only terminal diagnostics and assignments that prepare their arguments.
  class DiagnosticFallback
    def initialize(check)
      @check = check
      @needed = []
      @diagnostic_seen = false
    end

    def valid?(node)
      @check.statements(node).reverse_each.all? { |statement| accept?(statement) } && @diagnostic_seen
    end

    def accept?(statement)
      return accept_diagnostic?(statement) if @check.diagnostic?(statement)

      names = @check.assignment_names(statement)
      return false unless @diagnostic_seen && (names & @needed).any?

      @needed = (@needed - names) | @check.variable_reads(statement.right_expr)
      true
    end

    def accept_diagnostic?(statement)
      @diagnostic_seen = true
      @needed |= @check.variable_reads(statement)
      true
    end
  end
end
