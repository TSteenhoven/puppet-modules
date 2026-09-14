# frozen_string_literal: true

require_relative '../../model'
require_relative '../../token_helpers'

require_relative '../../section_layout'
require_relative '../../variable_dependencies'

require_relative '../../checks/comment_spacing'

PuppetLint.new_check(:project_comment_spacing) do
  include ProjectLint::CommentSpacingCheck
end

require_relative '../../checks/resource_sections'

PuppetLint.new_check(:project_resource_sections) do
  include ProjectLint::ResourceSectionsCheck
end

require_relative '../../checks/variable_sections'

PuppetLint.new_check(:project_variable_sections) do
  include ProjectLint::VariableSectionsCheck
end

require_relative '../../checks/if_sections'

PuppetLint.new_check(:project_if_sections) do
  include ProjectLint::IfSectionsCheck
end

require_relative '../../checks/layout'

PuppetLint.new_check(:project_layout) do
  include ProjectLint::LayoutCheck
end

require_relative '../../checks/positive_flow'

PuppetLint.new_check(:project_positive_flow) do
  include ProjectLint::PositiveFlowCheck
end
