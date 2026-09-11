require_relative '../../model'

module ProjectLint
  # Track escaping through AST assignments. A name ending in _shell is never sufficient evidence.
  class ShellProvenance
    M = Model::M

    def initialize(model, scope)
      @model = model
      @scope = scope
    end

    def scope_of(parents)
      parents.reverse.find { |parent| parent.is_a?(M::NamedDefinition) || parent.is_a?(M::LambdaExpression) }
    end

    def escaped_call?(node)
      node.is_a?(M::CallNamedFunctionExpression) && node.functor_expr.value == 'stdlib::shell_escape' && node.arguments.length == 1
    end

    def sensitive?(node)
      node.is_a?(M::CallMethodExpression) && node.functor_expr.is_a?(M::NamedAccessExpression) &&
        node.functor_expr.left_expr.is_a?(M::QualifiedReference) && node.functor_expr.left_expr.cased_value == 'Sensitive' && node.functor_expr.right_expr.value == 'new'
    end

    # Results distinguish a shell word from a complete script and unknown runtime data.
    def classify(node, visited = [])
      case node
      when M::LiteralString, M::LiteralUndef then :static
      when M::LiteralList
        node.values.all? { |value| classify(value, visited) != :raw } ? :script : :raw
      when M::BlockExpression
        classify(node.statements.last, visited)
      when M::TextExpression, M::ParenthesizedExpression
        classify(node.expr, visited)
      when M::VariableExpression
        name = node.expr.value
        return :raw if visited.include?(name)
        assignments = @model.nodes.select do |candidate, parents|
          candidate.is_a?(M::AssignmentExpression) && candidate.left_expr.is_a?(M::VariableExpression) && candidate.left_expr.expr.value == name && scope_of(parents) == @scope
        end.map { |candidate, _| candidate.right_expr }
        return :raw if assignments.empty?

        values = assignments.map { |value| classify(value, visited + [name]) }.uniq
        return values.first if values.length == 1
        values.include?(:raw) ? :raw : :script
      when M::ConcatenatedString
        node.segments.all? { |segment| classify(segment, visited) != :raw } ? :script : :raw
      when M::CallNamedFunctionExpression
        return :word if escaped_call?(node)
        if %w[join concat flatten union].include?(node.functor_expr.value) && node.arguments.all? { |argument| classify(argument, visited) != :raw }
          :script
        else
          :raw
        end
      when M::CallMethodExpression
        if sensitive?(node)
          classify(node.arguments.first, visited)
        elsif node.functor_expr.is_a?(M::NamedAccessExpression) && node.functor_expr.right_expr.value == 'map' && node.lambda
          self.class.new(@model, node.lambda).classify(node.lambda.body, visited)
        else
          :raw
        end
      else
        :raw
      end
    end
  end
end

PuppetLint.new_check(:project_shell) do
  include ProjectLint::ModelCheck

  def check
    m = ProjectLint::Model::M
    model.nodes.each do |node, parents|
      next unless node.is_a?(m::AttributeOperation) && %w[command onlyif unless].include?(node.attribute_name)
      resource = parents.reverse.find { |parent| parent.is_a?(m::ResourceExpression) || parent.is_a?(m::ResourceDefaultsExpression) }
      next unless resource && (resource.is_a?(m::ResourceExpression) ? resource.type_name.value == 'exec' : resource.type_ref.cased_value == 'Exec')

      scope = parents.reverse.find { |parent| parent.is_a?(m::NamedDefinition) || parent.is_a?(m::LambdaExpression) }
      provenance = ProjectLint::ShellProvenance.new(model, scope)
      if provenance.classify(node.value_expr) == :raw
        issue(node, 'Command data has no proven shell escaping origin; prepare dynamic words with stdlib::shell_escape before composing the command')
      end
    end
  end
end
