# frozen_string_literal: true

require_relative 'interfaces' unless defined?(ProjectLint::Interfaces)
require_relative '../../class_check_consumers'
require_relative '../../checks/class_check_reuse'

PuppetLint.new_check(:project_class_check_reuse) do
  include ProjectLint::ClassCheckReuseCheck
end
