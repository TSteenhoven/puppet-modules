# frozen_string_literal: true

require_relative 'test_helper'

# Shared setup and assertions for related lint contracts.
class AutofixTestCase < Minitest::Test
  include LintFixtureSupport

  FIXTURE_GROUP = 'autofix_test'

  include LintTestSupport

  def assert_fix(before, after, *rules)
    rules = nil if rules.empty?
    problems, unchanged = lint_checks(before, rules)
    refute_empty problems
    assert_equal before, unchanged
    problems, fixed = lint_checks(before, rules, fix: true)
    assert problems.any? { |problem| problem[:kind] == :fixed }, problems.inspect
    assert_equal after, fixed
    # This asserts the linter's output contract, not general repository syntax.
    ProjectLint::Model.new(fixed)
    assert_clean_passes(fixed, rules)
  end
end
