# frozen_string_literal: true

require_relative 'check_test_case'

# Verify the resource contract contract with native lint diagnostics.
class ResourceContractTest < CheckTestCase
  def test_package_removal_and_non_apt_provider
    assert_empty findings("package { 'demo': ensure => purged }", 'project_packages')
    assert_empty findings("package { 'demo': provider => gem }", 'project_packages')
    refute_empty findings("package { 'demo': ensure => installed }", 'project_packages')
    valid = fixture(:valid)
    assert_empty findings(valid, 'project_packages')
  end

  def test_resource_defaults_apply_to_files_and_packages
    assert_empty findings(fixture(:sample), 'project_files')
    assert_package_defaults
    refute_empty findings("file { '/tmp/example': ensure => file }", 'project_files')
    assert_empty findings("file { '/tmp/example': ensure => absent }", 'project_files')
    assert_empty findings(fixture(:sample3), 'project_files')
  end

  def test_source_content_exclusion_requires_a_real_guard
    code = fixture(:code)
    assert_empty findings(code, 'project_files')
    refute_empty findings(code.sub('$source == undef or $content == undef', '$source != undef or $content != undef'),
                          'project_files')
    derived = fixture(:derived)
    assert_empty findings(derived, 'project_files')
    refute_empty findings(derived.sub('$resolved = undef', '$resolved = $content'), 'project_files')
  end

  def test_numeric_and_hash_addition_remain_valid
    assert_empty findings('$x = 1 + 2', 'project_arrays')
    assert_empty findings("$x = { 'a' => 1 } + { 'b' => 2 }", 'project_arrays')
    refute_empty findings('$x = [1] + [2]', 'project_arrays')
    refute_empty findings('class example (Array[String] $items) { $all = $items + ["demo"] }', 'project_arrays')
    assert_empty findings('$x = concat([1], [2])', 'project_arrays')
    assert_empty findings(fixture(:sample), 'project_arrays')
  end

  def test_inheritance_and_overrides_require_catalog_review
    result = findings(fixture(:inherited), 'project_files')
    assert_equal 1, result.length
    assert result.first[:message].start_with?('[review]')
    assert_review_findings(fixture(:overridden))
    refute_empty findings(fixture(:nested), 'project_files')
  end

  def test_template_function_not_string_or_comment
    assert_empty findings("$x = template('example/config') # epp('example/config')", 'project_templates')
    assert_empty findings('$x = "epp(\'example/config\')"', 'project_templates')
    refute_empty findings("$x = epp('example/config.epp')", 'project_templates')
  end

  def test_heredoc_content_is_not_puppet_code
    code = fixture(:code)
    %w[project_templates project_arrays project_suppressions].each { |rule| assert_empty findings(code, rule) }
  end

  def assert_package_defaults
    assert_empty findings(fixture(:sample2), 'project_packages')
    assert_empty findings(fixture(:sample4), 'project_packages')
    refute_empty findings(fixture(:sample5), 'project_packages')
    refute_empty findings(fixture(:sample6), 'project_packages')
  end

  def assert_review_findings(code)
    assert(findings(code, 'project_files').all? { |finding| finding[:message].start_with?('[review]') })
  end
end
