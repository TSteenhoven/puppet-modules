# frozen_string_literal: true

require_relative '../section_layout'
require_relative '../variable_dependencies'
require_relative '../variable_group'

module ProjectLint
  # Require explanations at variable-group boundaries and offer conservative grouping hints.
  module VariableSectionsCheck
    include SectionLayout
    include VariableDependencies

    def check
      @starts = section_starts
      @positions = token_positions
      model.each_node { |node, parents| inspect_opening(node, parents.last) }
      model.each_node(Model::M::BlockExpression) do |block, _parents|
        group = VariableGroup.new(self, @starts)
        block.statements.each { |node| group.inspect_assignment(node) }
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
      node.is_a?(Model::M::CallNamedFunctionExpression) && !node.lambda
    end

    def following_assignments(node, parent)
      names = assignment_names(node)
      parent.statements.drop(parent.statements.index(node) + 1).take_while do |following|
        assignment_names(following).any? && (variable_reads(following.right_expr) & names).empty?
      end
    end

    # A shared call is a review candidate, not proof that evaluation can be moved.
    def grouping_hint(node, parent)
      return '' unless parent.is_a?(Model::M::BlockExpression) && ordinary_call?(node.right_expr)

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
  end
end
