# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'guarded_packages_support'

# Verify exact native fixes, parser validity and stability after a second scan/fix.
class GuardedPackagesFixTest < Minitest::Test
  include LintTestSupport
  include GuardedPackagesSupport

  RULE = :project_guarded_packages

  def test_fix_calls_ensure_packages_directly
    assert_fix(pair, merged, count: 1)
    assert_fix(pair.sub('class example', 'define example'), merged.sub('class example', 'define example'), count: 1)
  end

  def test_existing_conflicting_declarations_do_not_get_filtered_out
    existing = "package { 'alpha': ensure => latest, }\n"
    assert_fix(existing + pair, existing + merged, count: 1)
  end

  def test_three_packages_keep_declaration_order
    before = manifest(guard('alpha'), guard('beta'), guard('aardvark'))
    after = merged.sub("      'beta',\n", "      'beta',\n      'aardvark',\n")
    assert_fix(before, after, count: 1)
  end

  def test_install_options_and_nested_literals_are_preserved
    attributes = "ensure => installed, install_options => ['--no-install-recommends', '--no-install-suggests'],"
    settings = "'ensure'          => 'installed',\n      " \
               "'install_options' => ['--no-install-recommends', '--no-install-suggests'],"
    after = merged.sub("'ensure' => 'installed',", settings)
    assert_fix(pair(attributes), after, count: 1)
    extra = "ensure => installed, install_options => [{'config' => 'synthetic'}], noop => false, loglevel => undef,"
    problems, fixed = lint(pair(extra), fix: true)
    assert_equal([:fixed], problems.map { |problem| problem[:kind] })
    assert_includes fixed, "[{'config' => 'synthetic'}]"
    assert_clean_passes(fixed)
  end

  def test_preceding_comment_is_kept
    before = pair.sub('  if', "  # Install the command line tools.\n  if")
    after = merged.sub('  ensure_packages', "  # Install the command line tools.\n  ensure_packages")
    assert_fix(before, after, count: 1)
  end

  def test_multiple_scopes_are_fixed_independently
    before = pair + pair.sub('class example', 'define other')
    after = merged + merged.sub('class example', 'define other')
    assert_fix(before, after, count: 2)
  end

  def test_multiple_groups_are_fixed_atomically
    code = manifest(guard('alpha'), guard('beta'), guard('gamma', 'ensure => installed, noop => true,'),
                    guard('delta', 'ensure => installed, noop => true,'))
    problems, fixed = lint(code, fix: true)
    assert_equal(%i[fixed fixed], problems.map { |problem| problem[:kind] })
    assert_clean_passes(fixed)
  end
end
