# frozen_string_literal: true

require_relative 'cli_test_case'

# Verify first-party discovery, vendored exclusions and externally resolved consumers.
class CliScopeTest < CliTestCase
  def test_class_check_consumers_are_resolved_in_the_configured_modulepath
    write_source(fixture(:sample), path: 'example/manifests/init.pp')
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
    copy_linter(@directory)
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
end
