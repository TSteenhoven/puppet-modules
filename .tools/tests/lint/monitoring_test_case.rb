# frozen_string_literal: true

require_relative 'test_helper'

# Shared setup and assertions for related lint contracts.
class MonitoringTestCase < Minitest::Test
  include FindingValues
  include LintFixtureSupport

  FIXTURE_GROUP = 'monitoring_test'

  TARGET = "basic_settings::monitoring_custom { 'synthetic': }"

  PACKAGE = '$basic_settings::monitoring::package'

  def findings(code)
    lint = PuppetLint.new
    lint.path = 'example.pp'
    lint.code = code
    lint.run
    lint.problems.select { |problem| problem[:check] == :project_monitoring_backend }
  end

  def alias_decision
    <<~PUPPET
      $engine = #{PACKAGE}
      $chosen = $engine == 'synthetic_backend'
      notice('Unrelated preparation')
      $active = $ensure == present and $chosen
      if $active { if $ready { #{TARGET} } }
    PUPPET
  end

  def assert_destructured_backend
    code = "[$backend, $application] = [#{PACKAGE}, 'nginx']\nif $application == 'nginx' { #{TARGET} }"
    assert_empty findings(code)
    assert_equal 1, findings(code.sub("$application == 'nginx'", "$backend == 'synthetic_backend'")).length
  end

  def assert_class_wrappers
    %w[include contain require].each do |function|
      code = "class example { #{TARGET} }\nif #{PACKAGE} == 'synthetic_backend' { #{function} example }"
      assert_equal([2], finding_lines(code))
    end
  end
end
