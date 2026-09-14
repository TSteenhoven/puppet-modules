# frozen_string_literal: true

require_relative 'test_helper'

# Shared setup and assertions for related lint contracts.
class DocumentationTestCase < Minitest::Test
  include LintFixtureSupport

  FIXTURE_GROUP = 'documentation_test'

  include LintTestSupport

  PROSE = 'This class manages console packages and keyboard configuration, preserves explicit settings, ' \
          'and uses the host defaults when no override is supplied.'

  def lint(code, fix: false, rule: :project_documentation_layout)
    lint_checks(code, [rule], fix: fix)
  end

  def document(body, declaration = 'class example {}')
    "# @summary Manages the example.\n#\n#{body}#\n# @api public\n#{declaration}\n"
  end

  def assert_clean(code)
    problems, fixed = lint(code, fix: true)
    assert_empty problems
    assert_equal code, fixed
  end

  def assert_fix(code, expected)
    problems, unchanged = lint(code)
    refute_empty problems
    assert_equal code, unchanged
    problems, fixed = lint(code, fix: true)
    assert problems.all? { |problem| problem[:kind] == :fixed }, problems.inspect
    assert_equal expected, fixed
    assert_clean(fixed)
    fixed
  end
end
