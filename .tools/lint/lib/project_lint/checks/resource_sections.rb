# frozen_string_literal: true

require 'project_lint/section_layout'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Require a separate explanation when a resource follows a closed block.
    module ResourceSections
      include SectionLayout

      RESOURCE_TYPES = [Ast::M::ResourceExpression, Ast::M::ResourceDefaultsExpression,
                        Ast::M::ResourceOverrideExpression].freeze

      def check
        @positions = token_positions
        @sections = comment_sections
        ast.each_node do |node, _parents|
          check_resource(node) if self.class::RESOURCE_TYPES.any? { |type| node.is_a?(type) }
        end
      end

      def previous_token(node)
        previous = @positions.fetch([node.line, node.pos]).prev_code_token
        previous = previous.prev_code_token if previous&.type == :SEMIC
        previous
      end

      def explained_resource?(node, previous)
        @sections.any? do |section|
          section.first.line > previous.line && comment_end_line(section.last) == node.line - 1
        end
      end

      def check_resource(node)
        previous = previous_token(node)
        return unless previous&.type == :RBRACE
        return if explained_resource?(node, previous)

        issue(node, 'Start a resource declaration after a closed block with a blank line ' \
                    'and a preceding explanatory comment')
      end
    end
    PuppetLint.new_check(:project_resource_sections) { include ResourceSections }
  end
end
