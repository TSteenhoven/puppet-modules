# frozen_string_literal: true

require_relative '../variable_dependencies'
require_relative '../branch_size'
require_relative '../diagnostic_fallback'
require_relative '../validation_structure'

module ProjectLint
  # Keep validation fallbacks terminal and place larger implementation branches first.
  module PositiveFlowCheck
    include VariableDependencies

    def statements(node)
      entries = node.is_a?(Model::M::BlockExpression) ? node.statements : [node].compact
      entries.grep_v(Model::M::Nop)
    end

    def diagnostic?(node)
      node.is_a?(Model::M::CallNamedFunctionExpression) &&
        %w[fail warning].include?(node.functor_expr.value.delete_prefix('::'))
    end

    def diagnostic_branch?(node)
      DiagnosticFallback.new(self).valid?(node)
    end

    def check
      @validation_guards = ValidationStructure.new(self).guards
      @fallbacks = @validation_guards.grep(Model::M::IfExpression).filter_map do |guard|
        guard.else_expr if diagnostic_branch?(guard.else_expr)
      end
      @positions = tokens.to_h { |token| [[token.line, token.column], token] }
      @branch_size = BranchSize.new
      model.each_node(Model::M::IfExpression) { |node, _parents| check_branch(node) }
    end

    def check_branch(node)
      return if @validation_guards.include?(node)
      return unless @branch_size.size(node.then_expr) < following_size(node.else_expr)

      issue(node, 'Put the larger code branch first and keep shorter handling in the final else; ' \
                  'preserve condition semantics and elsif priority')
    end

    # Compare individual elsif arms; explicit nested if expressions keep their own structural weight.
    def following_size(node)
      return 0 if @fallbacks.include?(node)

      if node.is_a?(Model::M::IfExpression) && @positions.fetch([node.line, node.pos]).type == :ELSIF
        [@branch_size.size(node.then_expr), following_size(node.else_expr)].max
      else
        @branch_size.size(node)
      end
    end
  end
end
