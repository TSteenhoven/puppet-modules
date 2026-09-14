# frozen_string_literal: true

require 'project_lint/ast'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Recognize array addition from local assignments and declared parameter types.
    module Arrays
      include AstCheck

      def array?(node, scope, seen = [])
        return true if node.is_a?(Ast::M::LiteralList)
        return false unless node.is_a?(Ast::M::VariableExpression)

        name = node.expr.value
        return false if seen.include?(name)

        array_source?(name, scope, seen)
      end

      def array_source?(name, scope, seen)
        ast.nodes.any? do |candidate, parents|
          next false unless ast.scope_of(parents).equal?(scope)

          array_parameter?(candidate, name) || array_assignment?(candidate, name, scope, seen)
        end
      end

      def array_parameter?(candidate, name)
        candidate.is_a?(Ast::M::Parameter) && candidate.name == name &&
          ast.named_type?(candidate.type_expr, 'Array')
      end

      def array_assignment?(candidate, name, scope, seen)
        return false unless candidate.is_a?(Ast::M::AssignmentExpression)

        left = candidate.left_expr
        left.is_a?(Ast::M::VariableExpression) && left.expr.value == name &&
          array?(candidate.right_expr, scope, seen + [name])
      end

      def check
        ast.each_node(Ast::M::ArithmeticExpression) do |node, parents|
          next unless node.operator == '+'

          scope = ast.scope_of(parents)
          next unless array?(node.left_expr, scope) || array?(node.right_expr, scope)

          issue(node, 'Combine arrays with concat(...) while preserving element order')
        end
      end
    end
    PuppetLint.new_check(:project_arrays) { include Arrays }
  end
end
