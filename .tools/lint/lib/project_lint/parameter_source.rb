# frozen_string_literal: true

require 'project_lint/ast'
require 'puppet/pops/evaluator/json_strict_literal_evaluator'

module ProjectLint
  # Follow local assignments and parameter defaults without confusing defaults with fixed values.
  class ParameterSource
    def initialize(ast)
      @ast = ast
      # AST equality ignores source locations; identical variable names can belong to different scopes.
      @parents = {}.compare_by_identity
      ast.nodes.each { |node, parents| @parents[node] = parents }
      @literals = Puppet::Pops::Evaluator::JsonStrictLiteralEvaluator.new
    end

    def unwrap(node)
      node = node.expr while node.is_a?(Ast::M::ParenthesizedExpression)
      node
    end

    def literal(node)
      node = unwrap(node)
      if node.is_a?(Ast::M::UnaryMinusExpression)
        value = literal(node.expr)&.first
        return [-value] if value.is_a?(Numeric)

        return
      end
      # Wrap values so known undef/false remain distinct from an unknown expression.
      catch(:not_literal) { [@literals.literal(node)] }
    end

    def value(node, seen = [])
      node = unwrap(node)
      return if seen.any? { |previous| previous.equal?(node) }
      return variable_value(node, seen + [node]) if node.is_a?(Ast::M::VariableExpression)

      known = literal(node)
      { value: known.first, default: false } if known
    end

    def variable_value(node, seen)
      parents = @parents.fetch(node, [])
      if assignments(node, parents).empty?
        parameter_value(node, parents, seen)
      else
        value(local_value(node, parents), seen)
      end
    end

    def parameter_value(node, parents, seen)
      scope = @ast.scope_of(parents)
      return unless scope.is_a?(Ast::M::HostClassDefinition) || scope.is_a?(Ast::M::ResourceTypeDefinition)

      parameter = scope.parameters.find { |item| item.name == node.expr.value }
      return unless parameter

      value(parameter.value, seen)&.merge(default: true)
    end

    def local_value(variable, parents)
      candidates = assignments(variable, parents)
      return unless candidates.one?

      assignment, ancestors = candidates.first
      return unless assignment.offset < variable.offset && ancestors.all? { |parent| parents.include?(parent) }

      assignment.right_expr
    end

    def assignments(variable, parents)
      @ast.each_node(Ast::M::AssignmentExpression).select do |assignment, ancestors|
        target = assignment.left_expr
        target.is_a?(Ast::M::VariableExpression) && target.expr.value == variable.expr.value &&
          @ast.scope_of(ancestors).equal?(@ast.scope_of(parents))
      end
    end
  end
end
