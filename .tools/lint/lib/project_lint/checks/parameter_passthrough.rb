# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/parameter_filter'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Keep identity-only parameter forwarding visible at the resource declaration.
    module ParameterPassthrough
      include AstCheck

      def check
        @source = ParameterSource.new(ast)
        @filter = ParameterFilter.new(ast, @source)
        ast.each_node(Ast::M::AttributesOperation) do |operation, parents|
          check_forwarding(operation, parents)
        end
      end

      def check_forwarding(operation, parents)
        source, filters = source_hash(operation.expr, parents)
        return unless source.is_a?(Ast::M::LiteralHash) && !source.entries.empty?

        forwarding_problems(operation, source, filters, parents).each { |node, message| issue(node, message) }
      end

      def forwarding_problems(operation, source, filters, parents)
        if filters.empty?
          return [] unless source.entries.all? { |entry| matching_pair?(entry) }

          [[operation, '[review] Pass same-named variables directly as resource attributes']]
        else
          @filter.redundant_entries(source, filters, parents).map do |entry|
            [entry.key, '[review] Pass this key directly: its source value/default matches the receiving default; ' \
                        'review effective values and other hash consumers']
          end
        end
      end

      def matching_pair?(entry)
        key = entry.key
        value = entry.value
        value = value.expr while value.is_a?(Ast::M::ParenthesizedExpression)
        (key.is_a?(Ast::M::LiteralString) || key.is_a?(Ast::M::QualifiedName)) &&
          value.is_a?(Ast::M::VariableExpression) && key.value == value.expr.value
      end

      def source_hash(node, parents)
        filters = []
        node = unfiltered(node, filters)
        node = unfiltered(@source.local_value(node, parents), filters) if node.is_a?(Ast::M::VariableExpression)
        [node, filters]
      end

      def unfiltered(node, filters)
        return unfiltered(node.expr, filters) if node.is_a?(Ast::M::ParenthesizedExpression)
        return node unless filter_call?(node)

        filters << node
        unfiltered(node.functor_expr.left_expr, filters)
      end

      def filter_call?(node)
        node.is_a?(Ast::M::CallMethodExpression) && node.arguments.empty? &&
          node.functor_expr.is_a?(Ast::M::NamedAccessExpression) && node.functor_expr.right_expr.value == 'filter'
      end
    end
    PuppetLint.new_check(:project_parameter_passthrough) { include ParameterPassthrough }
  end
end
