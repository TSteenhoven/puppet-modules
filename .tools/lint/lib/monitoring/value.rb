# frozen_string_literal: true

module ProjectLint
  # Values tracked by the monitoring analysis; no Puppet expression is executed.
  module Monitoring
    M = Model::M
    TARGET = 'basic_settings::monitoring_custom'
    Value = Struct.new(:backend, :literal, :decisions)
  end
end
