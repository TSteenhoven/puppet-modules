# frozen_string_literal: true

require_relative 'cli_test_case'
require_relative 'cli_configuration_support'

# Verify that project configuration isolates personal options while leaving standard checks enabled.
class CliConfigurationTest < CliTestCase
  include CliConfigurationSupport

  def test_project_configuration_isolates_system_and_personal_options_before_scanning_or_fixing
    prepare_personal_configuration
    assert_personal_fix_effect
    assert_explicit_configuration_boundary
    assert_explicit_fix
    assert_invalid_configuration_boundaries
  end

  def test_native_config_option_silently_skips_a_missing_file_without_loading_project_checks
    config = File.join(@directory, 'missing.rc')
    assert_cli_success('--no-config', '--config', config, '--list-checks', project_config: false)
    assert_includes @output.lines.map(&:strip), 'double_quoted_strings'
    refute @output.lines.any? { |line| line.start_with?('project_') }, @output
  end

  def test_default_and_project_checks_are_present_and_enabled
    refute_match(/--only-checks\b/, File.read('.puppet-lint.rc'))
    assert PuppetLint.configuration.puppet_url_without_modules_enabled?
    enabled = enabled_checks
    fixture(:required_checks).each { |check| assert_includes enabled, check.to_sym }
    assert_cli_success('--list-checks')
    assert_listed_checks(enabled)
    assert_includes enabled, :project_resource_references
    assert_includes enabled, :project_documentation_layout
  end

  def assert_listed_checks(enabled)
    listed = @output.lines.map(&:strip)
    enabled.each { |check| assert_includes listed, check.to_s }
  end

  def enabled_checks
    PuppetLint.configuration.checks.select { |check| PuppetLint.configuration.public_send("#{check}_enabled?") }
  end

  def test_a_new_default_check_is_not_disabled_by_the_project_configuration
    plugin = write_file('future_check.rb', fixture(:sample))
    write_source("$values = concat([1], [2])\n", path: 'new.pp')
    output, errors, status = Open3.capture3(RbConfig.ruby, '-r', plugin, Gem.bin_path('puppet-lint', 'puppet-lint'),
                                            '--no-config', '--config', '.puppet-lint.rc', @file)
    refute status.success?, errors
    assert_includes output, 'future_default_check'
  end

  def test_invalid_options_and_missing_plugin_files_fail
    assert_cli_failure('--no-config', '--no-nonexistent-check', '.')
    assert_includes @output, 'invalid option'
    assert_cli_failure('--no-config', '--load=.tools/tests/lint/missing-plugin.rb', '.')
  end
end
