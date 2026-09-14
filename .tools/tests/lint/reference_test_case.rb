# frozen_string_literal: true

require_relative 'test_helper'

# Shared setup and assertions for related lint contracts.
class ReferenceTestCase < Minitest::Test
  include LintFixtureSupport

  FIXTURE_GROUP = 'resource_references_test'

  include LintTestSupport

  def lint(code, fix: false)
    lint_checks(code, [:project_resource_references], fix: fix)
  end

  def assert_fix(before, after, count: 1)
    assert_preserved(before, Array.new(count, :warning), fix: false)
    problems, fixed = lint(before, fix: true)
    assert_equal(Array.new(count, :fixed), problems.map { |problem| problem[:kind] })
    assert_equal after, fixed
    ProjectLint::Model.new(fixed)
    assert_clean_passes(fixed, [:project_resource_references])
  end

  def assert_preserved(code, kinds, review: false, fix: true)
    problems, fixed = lint(code, fix: fix)
    assert_equal(kinds, problems.map { |problem| problem[:kind] })
    assert_includes problems.first[:message], '[review]' if review
    assert_equal code, fixed
  end

  def assert_unchanged(code)
    problems, fixed = lint(code, fix: true)
    assert_empty problems
    assert_equal code, fixed
  end
end
