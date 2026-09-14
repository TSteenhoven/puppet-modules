# frozen_string_literal: true

require_relative '../section_layout'
require_relative '../variable_dependencies'
require_relative '../condition_preparation'

module ProjectLint
  # Place condition explanations before the complete local preparation chain.
  module IfSectionsCheck
    include SectionLayout
    include VariableDependencies

    def check
      @positions = token_positions
      @preparation = ConditionPreparation.new(self, @positions)
      @explained = explained_positions
      model.each_node(Model::M::IfExpression) { |node, parents| check_condition(node, parents) }
    end

    def explained_positions
      comment_sections.filter_map do |section|
        following = adjacent_code(section.last, :next_token)
        [following.line, following.column] if following
      end
    end

    def check_condition(node, parents)
      return if @positions.fetch([node.line, node.pos]).type == :ELSIF

      target = @preparation.start(node, parents)
      return if @explained.include?([target.line, target.pos])

      issue(target, 'Explain the conditional above its preparatory variable assignments, ' \
                    'or above the if/unless when there are none')
    end
  end
end
