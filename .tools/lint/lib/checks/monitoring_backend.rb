# frozen_string_literal: true

require_relative '../puppet-lint/plugins/interfaces' unless defined?(ProjectLint::Interfaces)
require_relative '../puppet-lint/plugins/layout' unless defined?(ProjectLint::VariableDependencies)

module ProjectLint
  # Implements the project_monitoring_backend check through the native Puppet-lint contract.
  module MonitoringBackendCheck
    include ProjectLint::ModelCheck

    def check
      analysis = ProjectLint::MonitoringBackendAnalysis.new(model)
      analysis.evaluate(model.program.body)
      analysis.warnings.sort_by { |node| [node.line, node.pos] }.each do |node|
        issue(node,
              'Delegate backend selection to basic_settings::monitoring_custom; callers may only distinguish ' \
              "package 'none' from enabled monitoring")
      end
    end
  end
end
