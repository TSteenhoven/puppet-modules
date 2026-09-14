# frozen_string_literal: true

require 'project_lint/section_layout'
require 'project_lint/variable_dependencies'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Place condition explanations before the complete local preparation chain.
    module IfSections
      include SectionLayout
      include AstCheck
      include VariableDependencies

      def check
        @positions = token_positions
        @explained = explained_positions
        ast.each_node(Ast::M::IfExpression) { |node, parents| check_condition(node, parents) }
      end

      def explained_positions
        comment_sections.filter_map do |section|
          following = adjacent_code(section.last, :next_token)
          [following.line, following.column] if following
        end
      end

      def check_condition(node, parents)
        return if @positions.fetch([node.line, node.pos]).type == :ELSIF

        target = preparation_start(node, parents)
        return if @explained.include?([target.line, target.pos])

        issue(target, 'Explain the conditional above its preparatory variable assignments, ' \
                      'or above the if/unless when there are none')
      end

      def preparation_start(node, parents)
        anchor, parent = assignment_anchor(node, parents)
        target = parent.is_a?(Ast::M::BlockExpression) ? dependency_start(node, anchor, parent) : anchor
        target.is_a?(Ast::M::AssignmentExpression) ? target.left_expr : target
      end

      def assignment_anchor(node, parents)
        parent = parents.last
        if parent.is_a?(Ast::M::AssignmentExpression) && parent.right_expr.equal?(node)
          [parent, parents[-2]]
        else
          [node, parent]
        end
      end

      def condition_reads(node)
        needed = variable_reads(node.test)
        following = node.else_expr
        while elsif?(following)
          needed |= variable_reads(following.test)
          following = following.else_expr
        end
        needed
      end

      def elsif?(node)
        node.is_a?(Ast::M::IfExpression) && @positions.fetch([node.line, node.pos]).type == :ELSIF
      end

      def dependency_start(node, anchor, parent)
        needed = condition_reads(node)
        target = anchor
        parent.statements.take(parent.statements.index(anchor)).reverse_each do |previous|
          names = assignment_names(previous)
          break if (names & needed).empty?

          target = previous
          needed = (needed - names) | variable_reads(previous.right_expr)
        end
        target
      end
    end
    PuppetLint.new_check(:project_if_sections) { include IfSections }
  end
end
