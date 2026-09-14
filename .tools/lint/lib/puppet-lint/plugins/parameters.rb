# frozen_string_literal: true

require_relative '../../model'
require_relative '../../token_helpers'

require_relative '../../checks/parameter_order'

PuppetLint.new_check(:project_parameter_order) do
  include ProjectLint::ParameterOrderCheck
end

require_relative '../../checks/parameter_alignment'

PuppetLint.new_check(:project_parameter_alignment) do
  include ProjectLint::ParameterAlignmentCheck
end
