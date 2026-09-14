# frozen_string_literal: true

require_relative 'value'

module ProjectLint
  module Monitoring
    # Evaluate bindings in declaration-local and lambda-local environments.
    module Bindings
      def evaluate_variable(node, environment, *)
        name = node.expr.value.delete_prefix('::')
        environment.fetch(name) { Value.new(name == 'basic_settings::monitoring::package', nil, []) }
      end

      def evaluate_declaration(node, environment, *)
        local = declaration_environment(node, environment)
        evaluate(node.body, local, [], node.name)
        Value.new(false, nil, [])
      end

      def declaration_environment(node, environment)
        local = environment.dup
        sources = backend_parameters(node)
        node.parameters.each do |parameter|
          local[parameter.name] = if sources.include?(parameter.name)
                                    Value.new(true, nil, [])
                                  else
                                    evaluate(parameter.value, local, [], node.name)
                                  end
        end
        local
      end

      def evaluate_node(node, environment, _guards, owner)
        evaluate(node.body, environment.dup, [], owner)
        Value.new(false, nil, [])
      end

      def evaluate_lambda(node, environment, guards, owner)
        local = environment.dup
        (node.parameters.map(&:name) + local_names(node.body)).each { |name| local[name] = Value.new(false, nil, []) }
        evaluate(node.body, local, guards, owner)
      end

      def paired_assignment?(node, names)
        node.left_expr.is_a?(M::LiteralList) && node.right_expr.is_a?(M::LiteralList) &&
          node.left_expr.values.all?(M::VariableExpression) && names.length == node.right_expr.values.length
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
          environment[name] = Value.new(value.backend, value.literal, (value.decisions + guards).uniq)
        end
      end

      def assignment_result(values, guards, paired:)
        result = combine(values)
        result.literal = values.first.literal unless paired
        result.decisions |= guards
        result
      end
    end
  end
end
