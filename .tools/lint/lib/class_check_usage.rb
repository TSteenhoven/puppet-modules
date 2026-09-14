# frozen_string_literal: true

module ProjectLint
  # Count consumers of one assigned class check within its actual lexical scope.
  class ClassCheckUsage
    M = Model::M
    attr_reader :assignment

    def initialize(check, declaration, nodes, parents)
      @check = check
      @declaration = declaration
      @nodes = nodes
      @ancestors = parents.dup
      @ancestors.pop while @ancestors.last.is_a?(M::ParenthesizedExpression) || @ancestors.last.is_a?(M::NotExpression)
      @assignment = @ancestors.last
    end

    def assigned_variable?
      assignment.is_a?(M::AssignmentExpression) && assignment.left_expr.is_a?(M::VariableExpression)
    end

    def name
      assignment.left_expr.expr.value
    end

    def scope
      @ancestors.reverse.find { |parent| parent.is_a?(M::LambdaExpression) } || @declaration
    end

    def qualified_name
      "#{@declaration.name}::#{name}" if scope.equal?(@declaration) && @declaration.is_a?(M::HostClassDefinition)
    end

    def local_reads
      names = [name]
      qualified = qualified_name
      names.push(qualified, "::#{qualified}") if qualified
      @check.variable_reads(scope.body).count { |read| names.include?(read) }
    end

    def reads
      count = local_reads
      if qualified_name
        count += outside_reads
        count += ClassCheckConsumers.external_reads(qualified_name, PuppetLint::Data.path) if count < 2
      end
      count += template_reads if count < 2
      count
    end

    def outside_reads
      # The current buffer takes precedence over its disk version.
      @check.model.each_node(M::VariableExpression).count do |node, ancestors|
        !ancestors.include?(@declaration) && node.expr.value.delete_prefix('::') == qualified_name
      end
    end

    def template_reads
      @nodes.sum do |node, ancestors|
        template_call?(node) && visible_template?(ancestors) ? ClassCheckConsumers.template_reads(node, name) : 0
      end
    end

    def template_call?(node)
      node.is_a?(M::CallNamedFunctionExpression) && %w[template inline_template].include?(node.functor_expr.value)
    end

    def visible_template?(ancestors)
      return false unless ancestors.include?(scope)

      ancestors.drop_while { |ancestor| !ancestor.equal?(scope) }.drop(1).none? { |ancestor| shadows_name?(ancestor) }
    end

    def shadows_name?(ancestor)
      ancestor.is_a?(M::LambdaExpression) &&
        (ancestor.parameters.map(&:name) + @check.local_names(ancestor.body)).include?(name)
    end
  end
end
