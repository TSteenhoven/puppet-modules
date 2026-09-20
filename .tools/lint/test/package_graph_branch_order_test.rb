# frozen_string_literal: true

require_relative 'test_helper'

# Keep installation and transitive ordering evidence on the route where it actually exists.
class PackageGraphBranchOrderTest < Minitest::Test
  include LintTestSupport

  RULE = :project_exec_packages
  INSTALL = "ensure_packages('curl')"
  COMMAND = "exec { 'example': command => 'curl --version' }"

  def test_different_dependency_paths_may_prove_order_in_each_branch
    code = <<~PUPPET
      #{INSTALL}
      file { '/tmp/first': } file { '/tmp/second': }
      if $enabled { Package['curl'] -> File['/tmp/first'] -> Exec['example'] }
      else { Package['curl'] -> File['/tmp/second'] ~> Exec['example'] }
      #{COMMAND}
    PUPPET
    assert_clean_passes(code)
  end

  def test_edges_from_opposite_branches_cannot_form_a_dependency_path
    code = "#{INSTALL} file { '/tmp/first': } " \
           "if $enabled { Package['curl'] -> File['/tmp/first'] } " \
           "else { File['/tmp/first'] -> Exec['example'] } #{COMMAND}"
    assert_includes findings(code).first[:message], 'no dependency path'
  end

  def test_ordering_in_only_one_branch_needs_review
    code = "#{INSTALL} if $enabled { Package['curl'] -> Exec['example'] } #{COMMAND}"
    problems = findings(code)
    assert_equal 1, problems.length
    assert_includes problems.first[:message], '[review]'
    assert_includes problems.first[:message], 'indirect execution order'
  end

  def test_installation_and_order_cannot_be_borrowed_from_different_branches
    code = "if $enabled { #{INSTALL} } else { Package['curl'] -> Exec['example'] } #{COMMAND}"
    assert_preserved(code, [:warning], review: true)
  end

  def test_conditional_before_notify_and_resource_defaults_are_used
    variants = ["if $enabled { package { 'curl': before => Exec['example'] } } " \
                "else { package { 'curl': notify => Exec['example'] } } #{COMMAND}",
                "#{INSTALL} File { require => Package['curl'] }; " \
                "if $enabled { file { '/tmp/first': before => Exec['example'] } } " \
                "else { file { '/tmp/second': notify => Exec['example'] } } #{COMMAND}"]
    variants.each { |code| assert_clean_passes(code) }
  end

  def test_parent_installations_and_class_ordering_are_proved_together
    code = "class example { if $enabled { #{INSTALL} } else { #{INSTALL} } } " \
           "class consumer { require example; #{COMMAND} }"
    assert_clean_passes(code)
    assert_includes findings(code.sub('require example', 'include example')).first[:message], 'no dependency path'
  end

  def test_independent_conditions_are_not_assumed_to_have_the_same_result
    code = "#{INSTALL} file { '/tmp/first': } " \
           "if $enabled { Package['curl'] -> File['/tmp/first'] } " \
           "if $enabled { File['/tmp/first'] -> Exec['example'] } #{COMMAND}"
    assert_preserved(code, [:warning], review: true)
  end

  def test_many_unrelated_conditions_do_not_obscure_a_complete_installation
    unrelated = 20.times.map { |i| "if $flag#{i} { ensure_packages('unrelated#{i}') }" }.join("\n")
    code = "#{unrelated} if $enabled { #{INSTALL} } else { #{INSTALL} } " \
           "exec { 'example': command => 'curl --version', require => Package['curl'] }"
    assert_clean_passes(code)
  end

  def test_analysis_budget_requests_review_instead_of_accepting_unexplored_routes
    choices = 130.times.map { |i| "'choice#{i}': { #{INSTALL} }" }.join("\n")
    code = "case $choice { 'missing': { notice('No installation') } #{choices} default: { #{INSTALL} } } " \
           "exec { 'example': command => 'curl --version', require => Package['curl'] }"
    assert_preserved(code, [:warning], review: true)
  end

  def test_analysis_budget_preserves_an_unconditional_installation_guarantee
    choices = 10.times.map { |i| "if $flag#{i} { Exec['example'] -> File['/tmp/part#{i}'] }" }.join("\n")
    message = findings("#{INSTALL} #{choices} #{COMMAND}").first[:message]
    assert_includes message, '[review]'
    assert_includes message, 'indirect execution order'
  end

  def test_dependencies_assigned_in_each_branch_keep_their_own_paths
    code = "#{INSTALL} file { '/tmp/first': require => Package['curl'] } " \
           "if $enabled { $dependency = Package['curl'] } else { $dependency = File['/tmp/first'] } " \
           "exec { 'example': command => 'curl --version', require => $dependency }"
    assert_clean_passes(code)
    assert_preserved(code.sub("require => Package['curl']", ''), [:warning], review: true)
  end
end
