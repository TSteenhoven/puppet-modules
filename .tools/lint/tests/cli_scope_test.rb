# frozen_string_literal: true

require_relative 'test_helper'

# Verify first-party discovery, vendored exclusions and externally resolved consumers.
class CliScopeTest < Minitest::Test
  include LintCliSupport

  def test_class_check_consumers_are_resolved_in_the_configured_modulepath
    write_source(fixture('cli_scope/in_the_configured_modulepath_sample'), path: 'example/manifests/init.pp')
    write_file('example/templates/state.erb', '<%= @enabled %>')
    options = ['--only-checks', 'project_class_check_reuse', @file]
    environment = { 'PROJECT_LINT_MODULEPATH' => @directory }
    assert_cli_success(*options, env: environment)
    write_file('example/templates/state.erb', '@enabled<%# @enabled is only mentioned in a comment. %>')
    assert_cli_failure(*options, env: environment)
    assert_includes @output, 'used only once'
    write_file('consumer/manifests/init.pp', 'class consumer { notice($example::enabled) }')
    assert_cli_success(*options, env: environment)
  end

  def test_cli_discovers_new_first_party_files_and_fails_on_a_project_check
    copy_project_config(@directory)
    write_source("$values = concat([1], [2])\n", path: 'new.pp')
    assert_cli_success('.', directory: @directory)
    write_source("$values = [1] + [2]\n", path: 'new.pp')
    assert_cli_failure('.', directory: @directory)
    assert_includes @output, 'new.pp:1:'
    assert_includes @output, 'project_arrays'
  end

  def vendored_gitlinks
    entries, status = Open3.capture2('git', 'ls-files', '--stage', '-z')
    assert status.success?
    links = entries.split("\0").select { |entry| entry.start_with?('160000 ') }
    links.map { |entry| entry.split("\t", 2).last }.sort
  end

  def expected_exclusions(gitlinks)
    paths = (gitlinks + %w[vendor/bundle]).flat_map { |path| ["./#{path}/*", "#{path}/*"] }
    paths + %w[./*/templates/*.yaml */templates/*.yaml ./*/templates/*.yml */templates/*.yml]
  end

  def test_vendored_gitlinks_are_the_only_excluded_module_directories
    gitlinks = vendored_gitlinks
    ignored = PuppetLint.configuration.ignore_paths
    assert_equal expected_exclusions(gitlinks).sort, ignored.sort
    gitlinks.each { |path| assert ignored_path?(ignored, "./#{path}/manifests/init.pp") }
    %w[./example/manifests/init.pp ./examples/example.pp].each { |path| refute ignored_path?(ignored, path) }
  end

  def ignored_path?(patterns, path)
    patterns.any? { |pattern| File.fnmatch(pattern, path) }
  end

  def test_file_arguments_and_first_directory_selection_have_distinct_semantics
    good = write_file('first/good.pp', "$values = concat([1], [2])\n")
    bad = write_file('second/bad.pp', "$values = [1] + [2]\n")
    assert_cli_success(good)
    assert_cli_failure(good, bad)
    assert_equal 1, @status.exitstatus
    assert_includes @output, 'project_arrays'
    assert_cli_success(File.dirname(good), File.dirname(bad))
    assert_empty @output
    assert_cli_failure(File.dirname(bad), File.dirname(good))
    assert_includes @output, 'project_arrays'
  end

  def test_zero_selected_files_succeeds_but_json_proves_the_empty_selection
    write_file('empty/.keep', '')
    assert_cli_success('--json', File.join(@directory, 'empty'))
    assert_equal [], JSON.parse(@output)
    good = write_file('good.pp', "$values = concat([1], [2])\n")
    assert_cli_success('--ignore-paths', good, '--json', good)
    assert_equal [], JSON.parse(@output)
  end
end
