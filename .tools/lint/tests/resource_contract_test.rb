# frozen_string_literal: true

require_relative 'test_helper'

# Verify the resource contract contract with native lint diagnostics.
class ResourceContractTest < Minitest::Test
  include LintTestSupport

  def test_package_removal_and_non_apt_provider
    assert_empty findings("package { 'demo': ensure => purged }", 'project_packages')
    assert_empty findings("package { 'demo': provider => gem }", 'project_packages')
    refute_empty findings("package { 'demo': ensure => installed }", 'project_packages')
    valid = "package { 'demo': install_options => ['--no-install-recommends', '--no-install-suggests'] }"
    assert_empty findings(valid, 'project_packages')
  end

  def test_a_documented_package_exception_has_no_automatic_acceptance_interface
    code = "# This synthetic package requires a recommended helper.\npackage { 'example': ensure => installed }\n"
    problems, unchanged = lint_checks(code, [:project_packages], fix: true)
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_includes problems.first[:message], 'tested central package exception'
    assert_equal code, unchanged
  end

  def test_resource_defaults_apply_to_files_and_packages
    assert_empty findings(
      "File { owner => 'root', group => 'root', mode => '0600' } file { '/tmp/example': ensure => file }",
      'project_files'
    )
    refute_empty findings("file { '/tmp/example': ensure => file }", 'project_files')
    assert_empty findings("file { '/tmp/example': ensure => absent }", 'project_files')
  end

  def test_links_require_ownership_without_file_modes
    assert_empty findings(
      "file { '/tmp/example': ensure => link, target => '/tmp/target', owner => 'root', group => 'root' }",
      'project_files'
    )
  end

  def test_source_content_exclusion_requires_a_real_guard
    code = fixture('resource_contract/requires_a_real_guard_code')
    assert_empty findings(code, 'project_files')
    refute_empty findings(code.sub('$source == undef or $content == undef', '$source != undef or $content != undef'),
                          'project_files')
    derived = fixture('resource_contract/requires_a_real_guard_derived')
    assert_empty findings(derived, 'project_files')
    refute_empty findings(derived.sub('$resolved = undef', '$resolved = $content'), 'project_files')
  end

  def test_numeric_and_hash_addition_remain_valid
    assert_empty findings('$x = 1 + 2', 'project_arrays')
    assert_empty findings("$x = { 'a' => 1 } + { 'b' => 2 }", 'project_arrays')
    refute_empty findings('$x = [1] + [2]', 'project_arrays')
    refute_empty findings('class example (Array[String] $items) { $all = $items + ["demo"] }', 'project_arrays')
    assert_empty findings('$x = concat([1], [2])', 'project_arrays')
    assert_empty findings(
      'class array_scope (Array $items) {} class number_scope (Integer $items) { $result = $items + 1 }',
      'project_arrays'
    )
  end

  def test_inheritance_and_overrides_require_catalog_review
    result = findings(
      "class parent { File { owner => 'root', group => 'root', mode => '0600' } } " \
      "class example inherits parent { file { '/tmp/example': } }", 'project_files'
    )
    assert_equal 1, result.length
    assert result.first[:message].start_with?('[review]')
    assert_review_findings(
      "file { '/tmp/example': } File['/tmp/example'] { owner => 'root', group => 'root', mode => '0600' }"
    )
  end

  def test_conditional_defaults_do_not_supply_unconditional_resources
    refute_empty findings(
      "if true { File { owner => 'root', group => 'root', mode => '0600' } } file { '/tmp/example': }", 'project_files'
    )
  end

  def test_template_function_not_string_or_comment
    assert_empty findings("$x = template('example/config') # epp('example/config')", 'project_templates')
    assert_empty findings('$x = "epp(\'example/config\')"', 'project_templates')
    refute_empty findings("$x = epp('example/config.epp')", 'project_templates')
  end

  def test_heredoc_content_is_not_puppet_code
    code = "$text = @(END)\nepp('demo.epp')\n$a = [1] + [2]\n# lint:ignore:140chars\nEND\n"
    %w[project_templates project_arrays project_suppressions].each { |rule| assert_empty findings(code, rule) }
  end

  def test_package_defaults_and_concat_include_both_apt_options
    assert_empty findings(
      "Package { install_options => ['--no-install-recommends', " \
      "'--no-install-suggests'] } package { 'demo': ensure => installed }", 'project_packages'
    )
    assert_empty findings(
      "package { 'demo': install_options => concat($options, " \
      "['--no-install-recommends', '--no-install-suggests']) }", 'project_packages'
    )
  end

  def test_unsafe_package_option_composition_requires_review
    refute_empty findings(
      "package { 'demo': install_options => union($options, " \
      "['--no-install-recommends', '--no-install-suggests']) }", 'project_packages'
    )
    refute_empty findings(
      "package { 'demo': install_options => ['--no-install-recommends', " \
      "'--no-install-suggests', '--install-recommends'] }", 'project_packages'
    )
  end

  def assert_review_findings(code)
    assert(findings(code, 'project_files').all? { |finding| finding[:message].start_with?('[review]') })
  end
end
