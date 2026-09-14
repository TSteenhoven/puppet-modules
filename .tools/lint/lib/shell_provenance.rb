# frozen_string_literal: true

require_relative 'model'

module ProjectLint
  # Distinguish escaped words, complete scripts and unknown data without trusting variable names.
  class ShellProvenance
    M = Model::M
    HANDLERS = {
      M::LiteralString => :classify_static, M::LiteralUndef => :classify_static,
      M::LiteralList => :classify_list, M::BlockExpression => :classify_block,
      M::TextExpression => :classify_parentheses, M::ParenthesizedExpression => :classify_parentheses,
      M::VariableExpression => :classify_variable, M::ConcatenatedString => :classify_string,
      M::CallNamedFunctionExpression => :classify_call, M::CallMethodExpression => :classify_method
    }.freeze

    def initialize(model, scope)
      @model = model
      @scope = scope
    end

    def classify(node, visited = [])
      handler = HANDLERS.find { |type, _method| node.is_a?(type) }&.last
      handler ? public_send(handler, node, visited) : :raw
    end

    def classify_static(*)
      :static
    end

    def classify_sequence(values, visited)
      values.all? { |value| classify(value, visited) != :raw } ? :script : :raw
    end

    def classify_list(node, visited)
      classify_sequence(node.values, visited)
    end

    def classify_block(node, visited)
      classify(node.statements.last, visited)
    end

    def classify_parentheses(node, visited)
      classify(node.expr, visited)
    end

    def classify_string(node, visited)
      classify_sequence(node.segments, visited)
    end

    def matching_assignment?(candidate, parents, name)
      left = candidate.left_expr
      left.is_a?(M::VariableExpression) && left.expr.value == name && @model.scope_of(parents) == @scope
    end

    def assignments(name)
      @model.each_node(M::AssignmentExpression).filter_map do |candidate, parents|
        candidate.right_expr if matching_assignment?(candidate, parents, name)
      end
    end

    def classify_variable(node, visited)
      name = node.expr.value
      return :raw if visited.include?(name)

      values = assignments(name).map { |value| classify(value, visited + [name]) }.uniq
      return :raw if values.empty?
      return values.first if values.length == 1

      values.include?(:raw) ? :raw : :script
    end

    def classify_call(node, visited)
      name = node.functor_expr.value
      return :word if name == 'stdlib::shell_escape' && node.arguments.length == 1
      return :raw unless %w[join concat flatten union].include?(name)

      classify_sequence(node.arguments, visited)
    end

    def sensitive?(node)
      member = node.functor_expr
      member.is_a?(M::NamedAccessExpression) && member.left_expr.is_a?(M::QualifiedReference) &&
        member.left_expr.cased_value == 'Sensitive' && member.right_expr.value == 'new'
    end

    def map_call?(node)
      node.functor_expr.is_a?(M::NamedAccessExpression) && node.functor_expr.right_expr.value == 'map' && node.lambda
    end

    def classify_method(node, visited)
      return classify(node.arguments.first, visited) if sensitive?(node)
      return self.class.new(@model, node.lambda).classify(node.lambda.body, visited) if map_call?(node)

      :raw
    end
  end
end
