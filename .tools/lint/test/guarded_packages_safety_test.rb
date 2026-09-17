# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'guarded_packages_support'

# Unsafe groups remain wholly unchanged, including when only a later guard is suppressed.
class GuardedPackagesSafetyTest < Minitest::Test
  include LintTestSupport
  include GuardedPackagesSupport

  RULE = :project_guarded_packages

  def test_relationships_dynamic_settings_aliases_and_implicit_ensure_need_review
    ["ensure => installed, require => File['/synthetic'],",
     "ensure => installed, notify => Service['synthetic'],",
     "ensure => installed, before => Package['synthetic'],",
     "ensure => installed, subscribe => File['/synthetic'],",
     'ensure => $version,', 'ensure => lookup("synthetic"),', 'ensure => present,',
     "ensure => installed, alias => 'synthetic',", "ensure => installed, name => 'synthetic',",
     'noop => true,', 'ensure => installed, ensure => installed,'].each do |attributes|
      assert_preserved(pair(attributes), [:warning], review: true)
    end
  end

  def test_extra_statements_and_else_are_reported_but_never_removed
    assert_preserved(pair(extra: "notice('synthetic')"), [:warning], review: true)
    assert_preserved(pair(extra: "notify { 'synthetic': }"), [:warning], review: true)
    assert_preserved(pair.gsub(/^  }$/, "  } else { notice('synthetic') }"), [:warning], review: true)
  end

  def test_one_unsafe_guard_prevents_fixing_the_entire_group
    code = manifest(guard('alpha'), guard('beta'), guard('gamma', extra: "notice('synthetic')"))
    assert_preserved(code, [:warning], review: true)
    interleaved = manifest(guard('alpha'), guard('gamma', 'ensure => latest,'),
                           guard('beta'), guard('delta', 'ensure => latest,'))
    assert_preserved(interleaved, %i[warning warning], review: true)
  end

  def test_resource_defaults_overrides_collectors_and_inheritance_prevent_fix
    ["Package { noop => true }\n", "Package['synthetic'] { noop => true }\n",
     "Package <| title == 'synthetic' |>\n"].each do |prefix|
      assert_preserved(prefix + pair, [:warning], review: true)
    end
    assert_preserved(pair.sub('class example', 'class example inherits parent'), [:warning], review: true)
    assert_preserved(pair.gsub('    package', '    @package'), [:warning], review: true)
  end

  def test_intervening_statements_comments_and_duplicate_titles_prevent_fix
    assert_preserved(manifest(guard('alpha'), "  notice('synthetic')\n", guard('beta')), [:warning], review: true)
    assert_preserved(manifest(guard('alpha'), "  # Keep this explanation.\n", guard('beta')), [:warning], review: true)
    assert_preserved(pair.gsub('ensure => installed,', "ensure => installed, # retained\n"), [:warning], review: true)
    assert_preserved(pair.gsub('beta', 'alpha'), [:warning], review: true)
  end

  def test_used_if_results_and_relationship_expressions_are_not_rewritten
    code = manifest("  $result = [\n#{guard('alpha')},\n#{guard('beta')}\n]\n")
    assert_preserved(code, [:warning], review: true)
    code = pair.sub("package { 'alpha'", "Package['synthetic'] -> package { 'alpha'")
    assert_clean_passes(code)
  end

  def test_suppressions_cover_the_first_or_later_guard
    first = "  # lint:ignore:project_guarded_packages\n"
    last = "  # lint:endignore\n"
    assert_preserved(manifest(first + guard('alpha') + last, guard('beta')), [:ignored])
    assert_preserved(manifest(guard('alpha'), first + guard('beta') + last), [:warning], review: true)
  end

  def test_nested_block_results_are_not_discarded
    body = pair.lines[1...-1].join
    assert_preserved(manifest("  $result = if true {\n#{body}  }\n"), [:warning], review: true)
  end

  def test_multiline_values_and_inline_groups_cannot_be_partially_changed
    assert_preserved(pair("ensure => installed, install_options => [\n      'synthetic',\n    ],"), [:warning])
    assert_preserved(pair.lines.map(&:strip).join(' '), [:warning])
    assert_preserved(pair.gsub('alpha') { "al\\'pha" }, [:warning], review: true)
  end
end
