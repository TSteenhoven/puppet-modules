# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'

# Install the packaged gem into an independent consumer bundle, without network access.
class ExternalProjectTest < Minitest::Test
  include InstalledGemSupport

  def test_installation_loads_all_checks_without_a_repository_checkout
    refute File.directory?(File.join(@installed, '.tools'))
    refute File.exist?(File.join(@installed, 'Gemfile'))
    refute File.exist?(File.join(@installed, 'tests'))
  end

  def test_installed_checks_are_registered_once
    lint('--list-checks')
    assert @status.success?, @output + @errors
    expected = PuppetLint.configuration.checks.grep(/^project_/).map(&:to_s)
    assert_equal expected.sort, @output.lines.map(&:strip).grep(/^project_/).sort
    assert_empty @errors
  end

  def test_installed_linter_accepts_clean_manifests
    lint('manifests')
    assert @status.success?, @output + @errors
    assert_empty @output
    assert File.file?(File.join(@project, 'Gemfile.lock'))
  end

  def test_native_scope_and_configuration_find_new_files_without_changing_sources
    write('manifests/new.pp', "$values = [1] + [2]\n")
    lint('manifests')
    refute @status.success?
    assert_includes @output, 'manifests/new.pp:1:'
    assert_includes @output, 'project_arrays'
    refute_includes @output, 'spec/invalid.pp'
    assert_equal "$values = [1] + [2]\n", read('manifests/new.pp')
  end

  def test_invalid_consumer_configuration_fails
    write('.puppet-lint.rc', "--invalid-consumer-option\n")
    lint('manifests')
    refute @status.success?
    assert_includes @output + @errors, 'invalid-consumer-option'
  end

  def test_native_fix_handles_upstream_and_project_edits_and_is_idempotent
    write('manifests/site.pp', "Notify['target'] -> [\n      File[\"/z\"],File[\"/a\"]\n]\n")
    lint('--fix', 'manifests')
    assert @status.success?, @output + @errors
    expected = "Notify['target'] -> File['/a', '/z']\n"
    assert_equal expected, read('manifests/site.pp')
    lint('--fix', 'manifests')
    assert @status.success?, @output + @errors
    assert_empty @output
    assert_equal expected, read('manifests/site.pp')
  end

  def test_modulepath_order_shadows_entire_modules_and_keeps_dependencies_outside_style_scope
    write('dependencies/profile/manifests/item.pp', 'define profile::item (String $value) {}')
    write('manifests/site.pp', "class { 'shared': }\nprofile::item { 'synthetic': }\n")
    lint('manifests')
    assert_equal 1, @output.scan('project_interface_calls: warning:').length, @output + @errors
    reverse_modulepath
    lint('manifests')
    assert_equal 2, @output.scan('project_interface_calls: warning:').length, @output + @errors
    refute_includes @output, 'project_documentation'
  end

  def test_explicit_modulepath_resolves_vendored_names_and_refuses_escaping_symlinks
    write('modules/stdlib/manifests/init.pp', 'class stdlib (String $value) {}')
    write('manifests/site.pp', "class { 'stdlib': }\n")
    lint('manifests')
    refute @status.success?
    assert_includes @output, 'project_interface_calls'
    write('outside/manifests/init.pp', 'class escaping (String $value) {}')
    File.symlink(File.join(@project, 'outside'), File.join(@project, 'modules/escaping'))
    write('manifests/site.pp', "class { 'escaping': }\n")
    lint('manifests')
    assert @status.success?, @output + @errors
  end

  def test_invalid_modulepaths_fail_even_without_calls
    ['', 'modules', File.join(@project, 'missing')].each do |value|
      @env['PROJECT_LINT_MODULEPATH'] = value
      lint('manifests')
      refute @status.success?
      assert_includes @output + @errors, 'PROJECT_LINT_MODULEPATH'
    end
  end

  def test_installed_check_finds_parent_results_in_the_consumer_modulepath
    write('modules/owner/manifests/init.pp', "class owner { $enabled = defined(Class['optional']) }")
    code = "define consumer { if defined(Class['owner']) { notice(defined(Class['optional'])) } }\n"
    write('manifests/site.pp', code)
    lint('--only-checks=project_class_check_reuse', 'manifests')
    refute @status.success?, @output + @errors
    assert_includes @output, 'Reuse $owner::enabled'
    write('manifests/site.pp', code.sub("notice(defined(Class['optional']))", 'notice($owner::enabled)'))
    lint('--only-checks=project_class_check_reuse', 'manifests')
    assert @status.success?, @output + @errors
  end

  def test_invalid_syntax_is_reported_and_fix_does_not_write
    code = 'class broken (String $value = ) {}'
    write('manifests/site.pp', code)
    lint('--fix', 'manifests')
    refute @status.success?
    assert_includes @output, 'Invalid Puppet syntax'
    assert_equal code, read('manifests/site.pp')
  end

  def test_missing_entrypoint_fails_clearly
    FileUtils.rm(File.join(@installed, 'lib/project_lint.rb'))
    lint('manifests')
    refute @status.success?
    assert_includes @errors, 'project_lint.rb'
  end
end
