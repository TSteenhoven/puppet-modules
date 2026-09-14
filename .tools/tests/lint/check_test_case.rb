# frozen_string_literal: true

require_relative 'test_helper'

# Share the native lint entry point and synthetic fixtures across check contracts.
class CheckTestCase < Minitest::Test
  include FindingValues
  include LintFixtureSupport

  FIXTURE_GROUP = 'checks_test'

  def findings(code, rule)
    lint = PuppetLint.new
    lint.path = 'example.pp'
    lint.code = code
    lint.run
    lint.problems.select { |problem| problem[:check].to_s == rule }
  end
end
