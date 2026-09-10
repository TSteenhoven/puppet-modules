require_relative 'interfaces' unless defined?(ProjectLint::Interfaces)
require_relative 'layout' unless defined?(ProjectLint::VariableDependencies)

module ProjectLint
  # Track backend-derived decisions without evaluating Puppet or guessing from variable names.
  class MonitoringBackendAnalysis
    include VariableDependencies

    TARGET = 'basic_settings::monitoring_custom'.freeze
    M = Model::M
    Value = Struct.new(:backend, :literal, :decisions)
    attr_reader :model, :warnings

    def initialize(model)
      @model = model
      @warnings = []
      @declarations = model.declarations.to_h { |declaration| [declaration.name, declaration] }
      @wrappers = {}
    end

    def combine(values)
      Value.new(values.any?(&:backend), nil, values.flat_map(&:decisions).uniq)
    end

    def resource_names(resource)
      name = resource.type_name.value.delete_prefix('::')
      return [name] unless name == 'class'

      resource.bodies.filter_map { |body| body.title.value if body.title.is_a?(M::LiteralString) }
    end

    def included_names(node)
      return [] unless node.is_a?(M::CallNamedFunctionExpression) && %w[include contain require].include?(node.functor_expr.value)

      node.arguments.flat_map { |argument| literal_names(argument) }
    end

    def literal_names(node)
      return [node.value.delete_prefix('::')] if node.is_a?(M::LiteralString) || node.is_a?(M::QualifiedName)
      return node.values.flat_map { |value| literal_names(value) } if node.is_a?(M::LiteralList)

      []
    end

    # Reuse the existing autoload resolver; a visited set bounds cyclic wrapper relationships.
    def wrapper?(name)
      return @wrappers[name] if @wrappers.key?(name)

      pending = [name]
      visited = []
      until pending.empty?
        candidate = pending.shift
        return @wrappers[name] = true if candidate == TARGET
        next if visited.include?(candidate)

        visited << candidate
        declaration = @declarations[candidate] || Interfaces.find(candidate)
        next unless declaration&.body

        [declaration.body, *model.descendants(declaration.body)].each do |child|
          pending.concat(child.is_a?(M::ResourceExpression) ? resource_names(child) : included_names(child))
        end
      end
      @wrappers[name] = false
    end

    # Parameters explicitly forwarded as a backend are sources too, including through local aliases.
    def backend_parameters(declaration)
      nodes = model.nodes.filter_map do |node, parents|
        next unless parents.include?(declaration)

        bound = parents.grep(M::LambdaExpression).flat_map { |lambda| lambda.parameters.map(&:name) + local_names(lambda.body) }
        [node, bound]
      end
      names = nodes.flat_map do |resource, bound|
        next [] unless resource.is_a?(M::ResourceExpression)
        next [] unless resource_names(resource).any? { |name| wrapper?(name) }

        resource.bodies.flat_map do |body|
          body.operations.select { |operation| operation.is_a?(M::AttributeOperation) && operation.attribute_name == 'package' }
              .flat_map { |operation| variable_reads(operation.value_expr) - bound }
        end
      end
      loop do
        previous = names.uniq
        nodes.each do |assignment, bound|
          names |= (variable_reads(assignment.right_expr) - bound) unless ((assignment_names(assignment) - bound) & names).empty?
        end
        break if previous == names.uniq
      end
      declaration.parameters.map(&:name) & names
    end

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
      labels.all? { |label| label.is_a?(M::LiteralDefault) || (label.is_a?(M::LiteralString) && label.value == 'none') }
    end

    def evaluate(node, environment = {}, guards = [], owner = nil)
      return Value.new(false, nil, []) unless node.is_a?(M::Positioned)

      case node
      when M::VariableExpression
        name = node.expr.value.delete_prefix('::')
        environment.fetch(name) { Value.new(name == 'basic_settings::monitoring::package', nil, []) }
      when M::LiteralString
        Value.new(false, node.value, [])
      when M::ParenthesizedExpression
        evaluate(node.expr, environment, guards, owner)
      when M::HostClassDefinition, M::ResourceTypeDefinition, M::FunctionDefinition
        local = environment.dup
        sources = backend_parameters(node)
        node.parameters.each do |parameter|
          local[parameter.name] = sources.include?(parameter.name) ? Value.new(true, nil, []) : evaluate(parameter.value, local, [], node.name)
        end
        evaluate(node.body, local, [], node.name)
        Value.new(false, nil, [])
      when M::NodeDefinition
        evaluate(node.body, environment.dup, [], owner)
        Value.new(false, nil, [])
      when M::LambdaExpression
        local = environment.dup
        (node.parameters.map(&:name) + local_names(node.body)).each { |name| local[name] = Value.new(false, nil, []) }
        evaluate(node.body, local, guards, owner)
      when M::BlockExpression
        node.statements.reduce(Value.new(false, nil, [])) { |_, statement| evaluate(statement, environment, guards, owner) }
      when M::AssignmentExpression
        names = assignment_names(node)
        paired = node.left_expr.is_a?(M::LiteralList) && node.right_expr.is_a?(M::LiteralList) &&
                 node.left_expr.values.all? { |left| left.is_a?(M::VariableExpression) } && names.length == node.right_expr.values.length
        values = (paired ? node.right_expr.values : [node.right_expr]).map { |right| evaluate(right, environment, guards, owner) }
        names.each_with_index do |name, index|
          value = values[paired ? index : 0]
          environment[name] = Value.new(value.backend, value.literal, (value.decisions + guards).uniq)
        end
        result = combine(values)
        result.literal = values.first.literal unless paired
        result.decisions |= guards
        result
      when M::IfExpression
        test = evaluate(node.test, environment, guards, owner)
        decisions = condition_decisions(test, node.test)
        branches = [environment.dup, environment.dup]
        values = [node.then_expr, node.else_expr].each_with_index.map do |branch, index|
          evaluate(branch, branches[index], guards + decisions, owner)
        end
        merge_branches(environment, branches)
        result = combine(values)
        result.decisions |= decisions
        result
      when M::CaseExpression, M::SelectorExpression
        selector = node.is_a?(M::SelectorExpression)
        test_node = selector ? node.left_expr : node.test
        test = evaluate(test_node, environment, guards, owner)
        options = selector ? node.selectors : node.options
        labels = options.flat_map { |option| selector ? [option.matching_expr] : option.values }
        decisions = test.decisions + (test.backend && !disabled_labels?(labels) ? [test_node] : [])
        decisions |= labels.flat_map { |label| condition_decisions(evaluate(label, environment, guards, owner), label) }
        branches = options.map { environment.dup }
        values = options.each_with_index.map do |option, index|
          evaluate(selector ? option.value_expr : option.then_expr, branches[index], guards + decisions, owner)
        end
        merge_branches(environment, branches)
        result = combine(values)
        result.decisions |= decisions
        result
      when M::ResourceExpression
        values = node.bodies.flat_map do |body|
          [body.title, *body.operations].map { |part| evaluate(part, environment, guards, owner) }
        end
        if owner != TARGET && resource_names(node).any? { |name| wrapper?(name) }
          @warnings |= guards + values.flat_map(&:decisions)
        end
        combine(values)
      else
        values = node.enum_for(:_pcore_contents).map { |child| evaluate(child, environment, guards, owner) }
        result = combine(values)
        if owner != TARGET && included_names(node).any? { |name| wrapper?(name) }
          @warnings |= guards + result.decisions
        end
        if node.is_a?(M::BinaryExpression) && result.backend
          allowed = node.is_a?(M::ComparisonExpression) && %w[== !=].include?(node.operator) && values.any? { |value| value.literal == 'none' }

          # Boolean composition preserves an unresolved backend read until it reaches a decision.
          unless node.is_a?(M::AndExpression) || node.is_a?(M::OrExpression)
            result.decisions << node unless allowed
            result.backend = false
          end
        end
        result
      end
    end
  end
end

PuppetLint.new_check(:project_monitoring_backend) do
  include ProjectLint::ModelCheck

  def check
    analysis = ProjectLint::MonitoringBackendAnalysis.new(model)
    analysis.evaluate(model.program.body)
    analysis.warnings.sort_by { |node| [node.line, node.pos] }.each do |node|
      issue(node, "Delegate backend selection to basic_settings::monitoring_custom; callers may only distinguish package 'none' from enabled monitoring")
    end
  end
end
