# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'guarded_packages_support'

# Group equivalent guards using their actual execution scope and package settings.
class GuardedPackagesTest < Minitest::Test
  include LintTestSupport
  include GuardedPackagesSupport

  RULE = :project_guarded_packages

  def test_two_and_three_packages_produce_one_diagnostic_at_the_first_guard
    [%w[alpha beta], %w[alpha beta gamma]].each do |names|
      problems = findings(manifest(*names.map { |name| guard(name) }))
      assert_equal 1, problems.length
      assert_equal [2, 3], problems.first.values_at(:line, :column)
      assert_equal "Multiple guarded package declarations can be combined using ensure_packages(): #{names.join(', ')}",
                   problems.first[:message]
    end
  end

  def test_different_attribute_names_values_and_types_do_not_group
    ['ensure => latest,', 'ensure => installed, install_options => [],',
     'ensure => true,', "ensure => 'true',"].each do |attributes|
      assert_clean_passes(manifest(guard('alpha'), guard('beta', attributes)))
    end
    assert_clean_passes(manifest(guard('alpha', "install_options => ['--first'],"),
                                 guard('beta', "install_options => ['--second'],")))
  end

  def test_attribute_order_and_bare_or_quoted_values_do_not_split_groups
    code = manifest(guard('alpha', 'ensure => installed, noop => true,'),
                    guard('beta', "noop => true, ensure => 'installed',"))
    assert_equal 1, findings(code).length
  end

  def test_single_guards_and_unmatched_titles_are_ignored
    assert_clean_passes(manifest(guard('alpha')))
    assert_clean_passes(pair.sub("package { 'beta'", "package { 'other'"))
    assert_clean_passes(pair.gsub("Package['", "Service['"))
    assert_clean_passes(pair.gsub('!defined', 'defined'))
    assert_clean_passes(pair.gsub('if (', 'unless ('))
  end

  def test_dynamic_titles_and_compound_conditions_are_not_candidates
    assert_clean_passes(pair.gsub("'alpha'", '$alpha').gsub("'beta'", '$beta'))
    assert_clean_passes(pair.gsub('!defined', '$enabled and !defined'))
    assert_clean_passes(pair.gsub("'alpha'", '"alpha-${version}"'))
  end

  def test_classes_and_defines_are_isolated
    assert_clean_passes(manifest(guard('alpha')) + manifest(guard('beta'), declaration: 'define other'))
    assert_equal 2, findings(pair + pair.sub('class example', 'define other')).length
  end

  def test_branches_lambdas_and_functions_are_isolated
    assert_clean_passes("class example {\nif $enabled {\n#{guard('alpha')}} else {\n#{guard('beta')}}\n}\n")
    assert_clean_passes("class example { [1].each |$value| {\n#{pair.lines[1...-1].join}} }\n")
    assert_clean_passes(pair.sub('class example', 'function example'))
  end

  def test_separate_settings_produce_independent_groups
    code = manifest(guard('alpha'), guard('beta'), guard('gamma', 'ensure => latest,'),
                    guard('delta', 'ensure => latest,'))
    assert_equal 2, findings(code).length
  end

  def test_comments_and_strings_do_not_create_declarations
    assert_clean_passes("# #{pair.lines.join('# ')}")
    assert_clean_passes("$example = '#{pair.gsub("'", '"')}'\n")
  end
end
