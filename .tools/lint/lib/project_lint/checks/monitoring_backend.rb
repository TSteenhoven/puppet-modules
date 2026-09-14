# frozen_string_literal: true

require 'project_lint/ast'
require 'project_lint/backend_provenance'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Implements the project_monitoring_backend check through the native Puppet-lint contract.
    module MonitoringBackend
      include ProjectLint::AstCheck

      def check
        analysis = BackendProvenance.new(ast)
        analysis.evaluate(ast.program.body)
        analysis.warnings.sort_by { |node| [node.line, node.pos] }.each do |node|
          issue(node,
                'Delegate backend selection to basic_settings::monitoring_custom; callers may only distinguish ' \
                "package 'none' from enabled monitoring")
        end
      end
    end
    PuppetLint.new_check(:project_monitoring_backend) { include MonitoringBackend }
  end
end
