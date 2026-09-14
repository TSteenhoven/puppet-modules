# frozen_string_literal: true

require_relative 'interfaces' unless defined?(ProjectLint::Interfaces)
require_relative '../../monitoring_backend_analysis'
require_relative '../../checks/monitoring_backend'

PuppetLint.new_check(:project_monitoring_backend) do
  include ProjectLint::MonitoringBackendCheck
end
