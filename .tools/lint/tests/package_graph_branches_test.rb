# frozen_string_literal: true

require_relative 'test_helper'

# Prove installations across choices without assuming parameter defaults or missing alternatives.
class PackageGraphBranchesTest < Minitest::Test
  include LintTestSupport

  RULE = :project_exec_packages
  INSTALL = "ensure_packages('curl')"
  COMMAND = "exec { 'example': command => 'curl --version', require => Package['curl'] }"

  def case_code(first, other = nil)
    fallback = "default: { #{other} }" if other
    "case $choice { 'full': { #{first} } #{fallback} }"
  end

  def test_complete_case_combines_regular_and_ensure_packages_installations
    first = "package { ['curl', 'jq']: ensure => installed }"
    assert_clean_passes("#{case_code(first, INSTALL)} #{COMMAND}")
  end

  def test_missing_default_retains_an_empty_route
    assert_preserved("#{case_code(INSTALL)} #{COMMAND}", [:warning], review: true)
  end

  def test_absent_dynamic_and_virtual_packages_in_one_route_do_not_prove_installation
    alternatives = ["package { 'curl': ensure => absent }", "package { 'curl': ensure => $state }",
                    "@package { 'curl': ensure => installed }", 'ensure_packages($packages)']
    alternatives.each do |other|
      assert_preserved("#{case_code(INSTALL, other)} #{COMMAND}", [:warning], review: true)
    end
  end

  def test_nested_case_and_if_choices_are_combined
    nested = "if $enabled { #{case_code(INSTALL, INSTALL)} } else { #{INSTALL} }"
    assert_clean_passes("#{case_code(nested, INSTALL)} #{COMMAND}")
    assert_preserved("#{case_code(nested.sub('else', 'elsif $other'), INSTALL)} #{COMMAND}",
                     [:warning], review: true)
  end

  def test_if_elsif_else_and_unless_support_complete_and_incomplete_choices
    complete = "if $first { #{INSTALL} } elsif $second { #{INSTALL} } else { #{INSTALL} }"
    assert_clean_passes("#{complete} #{COMMAND}")
    assert_clean_passes("unless $enabled { #{INSTALL} } else { #{INSTALL} } #{COMMAND}")
    %w[if unless].each do |keyword|
      assert_preserved("#{keyword} $enabled { #{INSTALL} } #{COMMAND}", [:warning], review: true)
    end
  end

  def test_only_the_consumers_route_needs_to_install_its_package
    assert_clean_passes(case_code("#{INSTALL} #{COMMAND}", "package { 'curl': ensure => absent }"))
    assert_clean_passes("if $enabled { #{INSTALL} #{COMMAND} }")
  end

  def test_literal_lists_and_local_values_are_resolved_in_each_branch
    code = "if $enabled { $packages = ['curl', 'jq']; ensure_packages($packages) } " \
           "else { $packages = ['curl']; stdlib::ensure_packages($packages) } #{COMMAND}"
    assert_clean_passes(code)
  end

  def test_required_parent_case_is_reused_by_a_nested_define
    parent = "class example { #{case_code(INSTALL, INSTALL)} }"
    consumer = "define example::task { if defined(Class['example']) { if $enabled { #{COMMAND} } } }"
    assert_clean_passes("#{parent} #{consumer}")
  end

  def test_class_includes_are_evaluated_separately_for_each_route
    code = "class first { #{INSTALL} } class second { #{INSTALL} } " \
           "if $enabled { include first } else { include second } #{COMMAND}"
    assert_clean_passes(code)
    assert_preserved(code.sub('include second', "notice('optional')"), [:warning], review: true)
  end

  def test_literal_and_regexp_labels_do_not_imply_a_default
    code = "case $choice { /full/: { #{INSTALL} } 'default': { #{INSTALL} } } #{COMMAND}"
    assert_preserved(code, [:warning], review: true)
  end

  def test_multiple_consumers_do_not_share_branch_decisions
    code = "if $enabled { #{INSTALL} #{COMMAND} } " \
           "else { #{COMMAND.sub('example', 'other')} }"
    problems = findings(code)
    assert_equal 1, problems.length
    assert_includes problems.first[:message], 'no package installation guarantee'
  end

  def test_branch_assigned_values_are_resolved_after_a_complete_choice
    assignments = "if $enabled { $packages = ['curl', 'jq'] } else { $packages = ['curl'] }"
    assert_clean_passes("#{assignments} ensure_packages($packages) #{COMMAND}")
    assert_preserved("#{assignments.sub("['curl']", "['jq']")} ensure_packages($packages) #{COMMAND}",
                     [:warning], review: true)
  end

  def test_routes_that_fail_compilation_do_not_require_runtime_packages
    assert_clean_passes("#{case_code(INSTALL, "fail('Unsupported choice')")} #{COMMAND}")
    assert_clean_passes("if $enabled { #{INSTALL} } else { ::fail('Unsupported') } #{COMMAND}")
    assert_clean_passes("fail('No catalog') #{COMMAND}")
    assert_preserved("#{case_code(INSTALL, "notice('No installation')")} #{COMMAND}", [:warning], review: true)
  end
end
