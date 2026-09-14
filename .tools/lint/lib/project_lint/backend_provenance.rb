# frozen_string_literal: true

require 'project_lint/variable_dependencies'
require 'project_lint/module_resolver'

module ProjectLint
  # Follow backend-derived decisions through lexical assignments and monitoring calls.
  class BackendProvenance
    TARGET = 'basic_settings::monitoring_custom'
    BackendValue = Struct.new(:backend, :literal, :decisions)

    include VariableDependencies

    HANDLERS = {
      Ast::M::VariableExpression => :evaluate_variable, Ast::M::LiteralString => :evaluate_literal,
      Ast::M::ParenthesizedExpression => :evaluate_parentheses,
      Ast::M::HostClassDefinition => :evaluate_declaration, Ast::M::ResourceTypeDefinition => :evaluate_declaration,
      Ast::M::FunctionDefinition => :evaluate_declaration, Ast::M::NodeDefinition => :evaluate_node,
      Ast::M::LambdaExpression => :evaluate_lambda, Ast::M::BlockExpression => :evaluate_block,
      Ast::M::AssignmentExpression => :evaluate_assignment, Ast::M::IfExpression => :evaluate_if,
      Ast::M::CaseExpression => :evaluate_selection, Ast::M::SelectorExpression => :evaluate_selection,
      Ast::M::ResourceExpression => :evaluate_resource
    }.freeze
    attr_reader :ast, :warnings

    def initialize(ast)
      @ast = ast
      @resolver = ModuleResolver.new
      @warnings = []
      @declarations = ast.declarations.to_h { |declaration| [declaration.name, declaration] }
      @wrappers = {}
    end

    def evaluate(node, environment = {}, guards = [], owner = nil)
      return BackendValue.new(false, nil, []) unless node.is_a?(Ast::M::Positioned)

      handler = HANDLERS.find { |type, _method| node.is_a?(type) }&.last || :evaluate_children
      public_send(handler, node, environment, guards, owner)
    end

    # Resolve monitoring wrappers and the parameters that feed their backend selection.
    module MonitoringCalls
      def resource_names(resource)
        name = resource.type_name.value.delete_prefix('::')
        return [name] unless name == 'class'

        resource.bodies.filter_map { |body| body.title.value if body.title.is_a?(Ast::M::LiteralString) }
      end

      def included_names(node)
        return [] unless node.is_a?(Ast::M::CallNamedFunctionExpression)
        return [] unless %w[include contain require].include?(node.functor_expr.value)

        node.arguments.flat_map { |argument| literal_names(argument) }
      end

      def literal_names(node)
        if node.is_a?(Ast::M::LiteralString) || node.is_a?(Ast::M::QualifiedName)
          return [node.value.delete_prefix('::')]
        end
        return node.values.flat_map { |value| literal_names(value) } if node.is_a?(Ast::M::LiteralList)

        []
      end

      def declaration_calls(name)
        declaration = @declarations[name] || @resolver.find(name)
        return [] unless declaration&.body

        [declaration.body, *ast.descendants(declaration.body)].flat_map do |child|
          child.is_a?(Ast::M::ResourceExpression) ? resource_names(child) : included_names(child)
        end
      end

      def wrapper?(name)
        @wrappers[name] = reaches_monitoring?(name) unless @wrappers.key?(name)
        @wrappers[name]
      end

      def reaches_monitoring?(name)
        pending = [name]
        visited = []
        until pending.empty?
          candidate = pending.shift
          return true if candidate == TARGET
          next if visited.include?(candidate)

          visited << candidate
          pending.concat(declaration_calls(candidate))
        end
        false
      end

      def scoped_nodes(declaration)
        ast.nodes.filter_map do |node, parents|
          next unless parents.include?(declaration)

          bound = parents.grep(Ast::M::LambdaExpression).flat_map do |lambda|
            lambda.parameters.map(&:name) + local_names(lambda.body)
          end
          [node, bound]
        end
      end

      def backend_parameters(declaration)
        nodes = scoped_nodes(declaration)
        names = nodes.flat_map { |resource, bound| forwarded_names(resource, bound) }
        names = resolve_aliases(nodes, names)
        declaration.parameters.map(&:name) & names
      end

      def forwarded_names(resource, bound)
        return [] unless resource.is_a?(Ast::M::ResourceExpression)
        return [] unless resource_names(resource).any? { |name| wrapper?(name) }

        resource.bodies.flat_map do |body|
          package_attributes(body).flat_map { |operation| variable_reads(operation.value_expr) - bound }
        end
      end

      def package_attributes(body)
        body.operations.select do |operation|
          operation.is_a?(Ast::M::AttributeOperation) && operation.attribute_name == 'package'
        end
      end

      def resolve_aliases(nodes, names)
        loop do
          previous = names.uniq
          nodes.each do |assignment, bound|
            next if ((assignment_names(assignment) - bound) & names).empty?

            names |= (variable_reads(assignment.right_expr) - bound)
          end
          return names if previous == names.uniq
        end
      end
    end

    # Propagate backend values through parameters, nested scopes and assignments.
    module LexicalBindings
      def evaluate_variable(node, environment, *)
        name = node.expr.value.delete_prefix('::')
        environment.fetch(name) { BackendValue.new(name == 'basic_settings::monitoring::package', nil, []) }
      end

      def evaluate_declaration(node, environment, *)
        local = declaration_environment(node, environment)
        evaluate(node.body, local, [], node.name)
        BackendValue.new(false, nil, [])
      end

      def declaration_environment(node, environment)
        local = environment.dup
        sources = backend_parameters(node)
        node.parameters.each do |parameter|
          local[parameter.name] = if sources.include?(parameter.name)
                                    BackendValue.new(true, nil, [])
                                  else
                                    evaluate(parameter.value, local, [], node.name)
                                  end
        end
        local
      end

      def evaluate_node(node, environment, _guards, owner)
        evaluate(node.body, environment.dup, [], owner)
        BackendValue.new(false, nil, [])
      end

      def evaluate_lambda(node, environment, guards, owner)
        local = environment.dup
        (node.parameters.map(&:name) + local_names(node.body)).each do |name|
          local[name] = BackendValue.new(false, nil, [])
        end
        evaluate(node.body, local, guards, owner)
      end

      def paired_assignment?(node, names)
        node.left_expr.is_a?(Ast::M::LiteralList) && node.right_expr.is_a?(Ast::M::LiteralList) &&
          node.left_expr.values.all?(Ast::M::VariableExpression) && names.length == node.right_expr.values.length
      end

      def evaluate_assignment(node, environment, guards, owner)
        names = assignment_names(node)
        paired = paired_assignment?(node, names)
        values = (paired ? node.right_expr.values : [node.right_expr]).map do |right|
          evaluate(right, environment, guards, owner)
        end
        assign_values(names, values, environment, guards, paired: paired)
        assignment_result(values, guards, paired: paired)
      end

      def assign_values(names, values, environment, guards, paired:)
        names.each_with_index do |name, index|
          value = values[paired ? index : 0]
          environment[name] = BackendValue.new(value.backend, value.literal, (value.decisions + guards).uniq)
        end
      end

      def assignment_result(values, guards, paired:)
        result = combine(values)
        result.literal = values.first.literal unless paired
        result.decisions |= guards
        result
      end
    end

    # Merge branch environments and retain backend-dependent control decisions.
    module BranchDecisions
      def condition_decisions(value, node)
        value.decisions + (value.backend ? [node] : [])
      end

      def merge_branches(environment, branches)
        branches.flat_map(&:keys).uniq.each do |name|
          values = branches.filter_map { |branch| branch[name] }
          environment[name] = combine(values)
          environment[name].literal = values.first.literal if values.map(&:literal).uniq.length == 1
        end
      end

      def disabled_labels?(labels)
        labels.all? { |label| label.is_a?(Ast::M::LiteralDefault) || (label.is_a?(Ast::M::LiteralString) && label.value == 'none') }
      end

      def evaluate_if(node, environment, guards, owner)
        test = evaluate(node.test, environment, guards, owner)
        decisions = condition_decisions(test, node.test)
        evaluate_branches([node.then_expr, node.else_expr], environment, guards, owner, decisions)
      end

      def evaluate_branches(nodes, environment, guards, owner, decisions)
        branches = nodes.map { environment.dup }
        values = nodes.each_with_index.map do |branch, index|
          evaluate(branch, branches[index], guards + decisions, owner)
        end
        merge_branches(environment, branches)
        result = combine(values)
        result.decisions |= decisions
        result
      end

      def selection_parts(node)
        if node.is_a?(Ast::M::SelectorExpression)
          [node.left_expr, node.selectors.flat_map do |option|
            [option.matching_expr]
          end, node.selectors.map(&:value_expr)]
        else
          [node.test, node.options.flat_map(&:values), node.options.map(&:then_expr)]
        end
      end

      def evaluate_selection(node, environment, guards, owner)
        test_node, labels, bodies = selection_parts(node)
        test = evaluate(test_node, environment, guards, owner)
        decisions = test.decisions + (test.backend && !disabled_labels?(labels) ? [test_node] : [])
        decisions |= labels.flat_map { |label| condition_decisions(evaluate(label, environment, guards, owner), label) }
        evaluate_branches(bodies, environment, guards, owner, decisions)
      end
    end

    def combine(values)
      BackendValue.new(values.any?(&:backend), nil, values.flat_map(&:decisions).uniq)
    end

    def evaluate_literal(node, *)
      BackendValue.new(false, node.value, [])
    end

    def evaluate_parentheses(node, environment, guards, owner)
      evaluate(node.expr, environment, guards, owner)
    end

    def evaluate_block(node, environment, guards, owner)
      node.statements.reduce(BackendValue.new(false, nil, [])) do |_previous, statement|
        evaluate(statement, environment, guards, owner)
      end
    end

    def evaluate_resource(node, environment, guards, owner)
      values = node.bodies.flat_map do |body|
        [body.title, *body.operations].map { |part| evaluate(part, environment, guards, owner) }
      end
      @warnings |= guards + values.flat_map(&:decisions) if calls_wrapper?(owner, resource_names(node))
      combine(values)
    end

    def calls_wrapper?(owner, names)
      owner != TARGET && names.any? { |name| wrapper?(name) }
    end

    def evaluate_children(node, environment, guards, owner)
      values = node.enum_for(:_pcore_contents).map { |child| evaluate(child, environment, guards, owner) }
      result = combine(values)
      @warnings |= guards + result.decisions if calls_wrapper?(owner, included_names(node))
      inspect_binary(node, result, values) if node.is_a?(Ast::M::BinaryExpression) && result.backend
      result
    end

    def allowed_comparison?(node, values)
      node.is_a?(Ast::M::ComparisonExpression) && %w[== !=].include?(node.operator) &&
        values.any? { |value| value.literal == 'none' }
    end

    def inspect_binary(node, result, values)
      # Boolean composition preserves unresolved reads until they reach a decision.
      return if node.is_a?(Ast::M::AndExpression) || node.is_a?(Ast::M::OrExpression)

      result.decisions << node unless allowed_comparison?(node, values)
      result.backend = false
    end
    include MonitoringCalls
    include LexicalBindings
    include BranchDecisions
  end
end
