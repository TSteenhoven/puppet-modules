# frozen_string_literal: true

require 'project_lint/parameter_source'

module ProjectLint
  # Distinguish fixed resource titles from arrays whose elements can be resource references.
  class ResourceValues
    def initialize(ast)
      @ast = ast
      @source = ParameterSource.new(ast)
      @parents = {}.compare_by_identity
      ast.nodes.each { |node, parents| @parents[node] = parents }
      @type_names = local_type_names
    end

    def local_type_names
      @ast.nodes.filter_map do |node, _parents|
        node.name.downcase if node.is_a?(Ast::M::TypeAlias) || node.is_a?(Ast::M::TypeDefinition)
      end
    end

    def reference?(node)
      return false unless node.is_a?(Ast::M::AccessExpression) && node.left_expr.is_a?(Ast::M::QualifiedReference)

      name = node.left_expr.value
      return false if name != 'class' && Puppet::Pops::Types::TypeParser.type_map.key?(name)

      !@type_names.include?(name)
    end

    def concat?(node)
      node.is_a?(Ast::M::CallNamedFunctionExpression) && !node.lambda &&
        %w[concat ::concat stdlib::concat ::stdlib::concat].include?(node.functor_expr.value)
    end

    def local_value(node)
      @source.local_value(node, @parents.fetch(node, []))
    end

    def first_argument?(call, node)
      @source.unwrap(call.arguments.first).equal?(node)
    end

    def names(node, seen = [])
      node = @source.unwrap(node)
      return if node.nil? || seen.any? { |previous| previous.equal?(node) }
      return names(local_value(node), seen + [node]) if node.is_a?(Ast::M::VariableExpression)
      return concatenated_names(node, seen) if concat?(node)

      literal_names(node)
    end

    def literal_names(node)
      return unless node.is_a?(Ast::M::LiteralList)

      value = @source.literal(node)&.first
      value if value&.all?(String)
    end

    def concatenated_names(node, seen)
      values = node.arguments.map { |argument| names(argument, seen + [node]) }
      values.flatten if values.length >= 2 && values.none?(&:nil?)
    end

    def array?(node, seen = [])
      node = @source.unwrap(node)
      return false if node.nil? || seen.any? { |previous| previous.equal?(node) }
      return true if node.is_a?(Ast::M::LiteralList) || concat?(node)
      return variable_array?(node, seen) if node.is_a?(Ast::M::VariableExpression)

      conditional_arrays?(node, seen)
    end

    def variable_array?(node, seen)
      value = local_value(node)
      return array?(value, seen + [node]) if value

      scope = @ast.scope_of(@parents.fetch(node, []))
      return false unless scope.respond_to?(:parameters)

      parameter = scope.parameters.find { |candidate| candidate.name == node.expr.value }
      parameter && @ast.named_type?(parameter.type_expr, 'Array')
    end

    def conditional_arrays?(node, seen)
      values = case node
               when Ast::M::SelectorExpression then node.selectors.map(&:value_expr)
               when Ast::M::IfExpression then [node.then_expr, node.else_expr]
               when Ast::M::BlockExpression then [node.statements.last]
               else []
               end
      !values.empty? && values.all? { |value| array?(value, seen + [node]) }
    end

    def reference_array?(references)
      keys = references.flat_map(&:keys)
      keys.length > 1 || (keys.one? && array?(keys.first))
    end
  end
end
