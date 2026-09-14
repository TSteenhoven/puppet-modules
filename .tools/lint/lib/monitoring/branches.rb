# frozen_string_literal: true

require_relative 'value'

module ProjectLint
  module Monitoring
    # Merge branch environments and retain decisions that depend on a backend.
    module Branches
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
        if node.is_a?(M::SelectorExpression)
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
  end
end
