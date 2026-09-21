# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'option_file_support'

# Verify that project configuration isolates personal options while leaving standard checks enabled.
class CliConfigurationTest < Minitest::Test
  include LintCliSupport
  include OptionFileSupport

  EXPECTED_CHECKS = %w[140chars documentation parameter_order selector_inside_resource
                       single_quote_string_with_variables class_inherits_from_params_class project_arrays
                       project_class_check_reuse project_comment_spacing project_documentation project_files
                       project_if_sections project_interface_calls project_layout project_monitoring_backend
                       project_packages project_parameter_alignment project_parameter_order
                       project_parameter_passthrough project_positive_flow
                       project_puppet_urls project_resource_sections project_shell project_suppressions
                       project_templates project_variable_sections].freeze

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
    EXPECTED_CHECKS.each do |check|
      assert_includes enabled, check.to_sym
    end
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
    code = File.read(File.join(__dir__, 'fixtures/future_default_check.rb'))
    plugin = write_file('future_check.rb', code)
    write_source("$values = concat([1], [2])\n", path: 'new.pp')
    output, errors, status = Open3.capture3(RbConfig.ruby, '-r', plugin, Gem.bin_path('puppet-lint', 'puppet-lint'),
                                            '--no-config', '--config', '.puppet-lint.rc', @file)
    refute status.success?, errors
    assert_includes output, 'future_default_check'
  end

  def test_invalid_options_and_missing_plugin_files_fail
    assert_cli_failure('--no-config', '--no-nonexistent-check', '.')
    assert_includes @output, 'invalid option'
    assert_cli_failure('--no-config', '--load=missing-plugin.rb', '.')
  end

  def test_repeated_configurations_replace_lists_and_formats_but_accumulate_boolean_flags
    first = write_file('first.rc', "--fix\n--ignore-paths=first/*\n--top-scope-variables=first\n--log-format=first\n")
    second = write_file('second.rc',
                        "--relative\n--ignore-paths=second/*\n--top-scope-variables=second\n--log-format=second\n")
    assert_equal [true, true, ['second/*'], ['second'], 'second'], configuration_values(first, second)
  end

  def test_relative_load_paths_use_the_working_directory_not_the_configuration_directory
    nested = write_file('nested/options.rc', "--load=plugin.rb\n")
    write_file('plugin.rb', "PuppetLint.new_check(:synthetic_loaded) { def check; end }\n")
    assert_cli_success('--no-config', '--config', nested, '--list-checks',
                       directory: @directory, project_config: false)
    assert_includes @output, 'synthetic_loaded'
    FileUtils.mv(File.join(@directory, 'plugin.rb'), File.join(@directory, 'nested/plugin.rb'))
    assert_cli_failure('--no-config', '--config', nested, '--list-checks',
                       directory: @directory, project_config: false)
    assert_equal 1, @status.exitstatus
    assert_includes @errors, 'LoadError'
  end

  def test_project_check_switches_are_not_added_after_native_option_parser_construction
    assert_cli_failure('--no-project_arrays-check', '--list-checks')
    assert_equal 1, @status.exitstatus
    assert_includes @output, 'invalid option'
    assert_cli_success('--only-checks', 'project_arrays', '--list-checks')
    assert_includes @output, 'project_arrays'
  end
end
