# frozen_string_literal: true

require 'project_lint/section_layout'
require 'project_lint/variable_dependencies'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Require explanations at variable-group boundaries and offer conservative grouping hints.
    module VariableSections
      include SectionLayout
      include AstCheck
      include VariableDependencies

      def check
        @starts = section_starts
        @positions = token_positions
        ast.each_node { |node, parents| inspect_opening(node, parents.last) }
        ast.each_node(Ast::M::BlockExpression) do |block, _parents|
          @annotated = false
          reset_group
          block.statements.each { |node| inspect_assignment(node) }
        end
      end

      def inspect_opening(node, parent)
        return if assignment_names(node).empty?

        position = [node.left_expr.line, node.left_expr.pos]
        return unless @positions.fetch(position).prev_code_token&.type == :LBRACE
        return if @starts.key?(position)

        message = 'Explain the variable group immediately inside the opening brace'
        issue(node.left_expr, message + grouping_hint(node, parent))
      end

      def ordinary_call?(node)
        node.is_a?(Ast::M::CallNamedFunctionExpression) && !node.lambda
      end

      def following_assignments(node, parent)
        names = assignment_names(node)
        parent.statements.drop(parent.statements.index(node) + 1).take_while do |following|
          assignment_names(following).any? && (variable_reads(following.right_expr) & names).empty?
        end
      end

      # A shared call is a review candidate, not proof that evaluation can be moved.
      def grouping_hint(node, parent)
        return '' unless parent.is_a?(Ast::M::BlockExpression) && ordinary_call?(node.right_expr)

        following_assignments(node, parent).each do |following|
          line = @starts[[following.left_expr.line, following.left_expr.pos]]
          next unless line && same_outer_call?(node.right_expr, following.right_expr)

          return "; consider the explained section at line #{line} with the same outer function, " \
                 'after checking purpose and evaluation order'
        end
        ''
      end

      def same_outer_call?(left, right)
        ordinary_call?(right) && left.functor_expr.value == right.functor_expr.value
      end

      def reset_group
        @linked = false
        @assigned = []
      end

      def inspect_assignment(node)
        names = assignment_names(node)
        if names.empty?
          @annotated = false
          return
        end
        start_group(node)
        inspect_dependency(node, names) if @annotated
      end

      def start_group(node)
        return unless @starts.key?([node.left_expr.line, node.left_expr.pos])

        @annotated = true
        reset_group
      end

      def inspect_dependency(node, names)
        related = (variable_reads(node.right_expr) & @assigned).any?
        if @linked && !related
          issue(node.left_expr, 'Start unrelated assignments after a dependent variable group with a blank line ' \
                                'and a new explanatory comment')
          reset_group
        end
        @linked ||= related
        @assigned.concat(names)
      end
    end
    PuppetLint.new_check(:project_variable_sections) { include VariableSections }
  end
end
