# frozen_string_literal: true

require_relative '../../model'
require_relative '../../strings_documentation'
require_relative '../../token_helpers'

require_relative '../../checks/documentation'

PuppetLint.new_check(:project_documentation) do
  include ProjectLint::DocumentationCheck
end

require_relative '../../checks/documentation_layout'

PuppetLint.new_check(:project_documentation_layout) do
  include ProjectLint::DocumentationLayoutCheck
end

require_relative '../../checks/suppressions'

PuppetLint.new_check(:project_suppressions) do
  include ProjectLint::SuppressionsCheck
end
