# frozen_string_literal: true

require_relative '../../model'
require_relative '../../token_helpers'

require_relative '../../checks/resource_references'

PuppetLint.new_check(:project_resource_references) do
  include ProjectLint::ResourceReferencesCheck
end
