# frozen_string_literal: true

require 'project_lint/parameter_source'

module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Identify resource branches that can share an existing outer condition.
    module SharedConditions
      include AstCheck

      def check
        @source = ParameterSource.new(ast)
        ast.each_node(Ast::M::BlockExpression) { |block, _parents| check_block(block) }
      end

      def check_block(block)
        candidates = block.statements.select do |statement|
          statement.instance_of?(Ast::M::IfExpression) && resource_work?(statement.then_expr)
        end
        candidates.group_by { |node| condition_key(leading_condition(node.test)) }.each do |key, branches|
          check_group(key, branches) if key && branches.length > 1
        end
      end

      def check_group(key, branches)
        owner = branches.find { |node| condition_key(node.test) == key }
        return unless owner

        branches.reject { |node| node.equal?(owner) }.each do |node|
          issue(node, "[review] Group resource declarations under the existing condition at line #{owner.line}; " \
                      'preserve additional conditions, fallback branches and evaluation order')
        end
      end

      def leading_condition(node)
        node = @source.unwrap(node)
        node = @source.unwrap(node.left_expr) while node.is_a?(Ast::M::AndExpression)
        node
      end

      def condition_key(node)
        node = @source.unwrap(node)
        case node
        when Ast::M::VariableExpression then [:variable, node.expr.value]
        when Ast::M::ComparisonExpression then comparison_key(node)
        when Ast::M::NotExpression
          nested = condition_key(node.expr)
          [:not, nested] if nested
        end
      end

      def comparison_key(node)
        variable = @source.unwrap(node.left_expr)
        return unless %w[== !=].include?(node.operator) && variable.is_a?(Ast::M::VariableExpression)

        literal = scalar_key(node.right_expr)
        [:comparison, node.operator, variable.expr.value, literal] if literal
      end

      def scalar_key(node)
        literal = @source.literal(node)
        return unless literal

        value = literal.first
        [value.class, value] unless value.is_a?(Array) || value.is_a?(Hash)
      end

      def resource_work?(node)
        return false unless node.is_a?(Ast::M::Positioned)
        return true if node.is_a?(Ast::M::AbstractResource)
        return true if node.is_a?(Ast::M::CallNamedFunctionExpression) &&
                       %w[realize include contain require ensure_packages stdlib::ensure_packages].include?(
                         node.functor_expr.value.delete_prefix('::')
                       )

        node.enum_for(:_pcore_contents).any? { |child| resource_work?(child) }
      end
    end
    PuppetLint.new_check(:project_shared_conditions) { include SharedConditions }
  end
end
