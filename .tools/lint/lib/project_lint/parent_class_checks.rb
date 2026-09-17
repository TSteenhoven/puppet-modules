# frozen_string_literal: true

require 'project_lint/module_resolver'

module ProjectLint
  # Find class-owned check results available through an enclosing positive class guard.
  class ParentClassChecks
    def initialize(check, resolver)
      @check = check
      @resolver = resolver
      @variables = {}
    end

    def replacement(call, parents, declaration)
      enclosing_classes(call, parents, declaration).each do |name|
        next if name == declaration.name

        variable = variables(name)[@check.class_check(call)]
        return "$#{name}::#{variable}" if variable
      end
      nil
    end

    def enclosing_classes(call, parents, declaration)
      path = parents.drop_while { |parent| !parent.equal?(declaration) } + [call]
      path.each_cons(2).flat_map do |parent, child|
        next [] unless parent.is_a?(Ast::M::IfExpression) && child.equal?(parent.then_expr)

        guarded_classes(parent.test)
      end
    end

    def guarded_classes(node)
      case node
      when Ast::M::ParenthesizedExpression then guarded_classes(node.expr)
      when Ast::M::AndExpression then guarded_classes(node.left_expr) + guarded_classes(node.right_expr)
      else Array(@check.class_check(node))
      end
    end

    def variables(name)
      @variables[name] ||= read_variables(name)
    end

    def read_variables(name)
      declaration = parent_declaration(name)
      return {} unless declaration.is_a?(Ast::M::HostClassDefinition) && declaration.body

      grouped = class_assignments(declaration).group_by { |node| node.left_expr.expr.value }
      grouped.filter_map { |variable, assignments| check_variable(variable, assignments) }.to_h
    end

    def parent_declaration(name)
      @check.ast.declarations.find { |item| item.name == name } || @resolver.find(name)
    end

    def check_variable(variable, assignments)
      return unless assignments.one? && !variable.include?('::')

      checked = @check.class_check(unwrapped(assignments.first.right_expr))
      [checked, variable] if checked
    end

    def class_assignments(declaration)
      assignments = []
      declaration._pcore_all_contents([]) do |node, parents|
        next unless node.is_a?(Ast::M::AssignmentExpression) && node.left_expr.is_a?(Ast::M::VariableExpression)
        next unless parents.include?(declaration.body) || node.equal?(declaration.body)
        next if parents.any? { |parent| nested_scope?(parent, declaration) }

        assignments << node
      end
      assignments
    end

    def nested_scope?(node, declaration)
      node.is_a?(Ast::M::LambdaExpression) || (node.is_a?(Ast::M::NamedDefinition) && !node.equal?(declaration))
    end

    def unwrapped(node)
      node = node.expr while node.is_a?(Ast::M::ParenthesizedExpression)
      node
    end
  end
end
