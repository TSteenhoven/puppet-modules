# frozen_string_literal: true

require_relative 'test_helper'

# Verify native diagnostic formats, selections and error exit statuses.
class CliDiagnosticsTest < Minitest::Test
  include LintCliSupport

  def test_project_cli_options_select_checks_show_ignored_and_preserve_json_diagnostics
    code = "$values = [1] + [2]\n$label = \"synthetic\"\n"
    write_source(code)
    assert_cli_failure('--only-checks', 'project_arrays', '--json', @file)
    problems = JSON.parse(@output).flatten
    assert_equal(['project_arrays'], problems.map { |problem| problem.fetch('check') })
    assert_equal code, source
    assert_selected_quote_fix(code)
    assert_ignored_diagnostics
  end

  def assert_selected_quote_fix(code)
    assert_cli_success('--only-checks', 'double_quoted_strings', '--fix', @file)
    assert_equal code.sub('"synthetic"', "'synthetic'"), source
    assert_cli_failure(@file)
    assert_includes @output, 'project_arrays'
  end

  def assert_ignored_diagnostics
    write_source("$label = '#{'x' * 150}' # lint:ignore:140chars\n")
    assert_cli_success('--show-ignored', @file)
    assert_equal 1, diagnostics(@output, '140chars').length
    assert_includes @output, ': ignored:'
  end

  def test_diagnostic_counts_are_independent_of_github_annotations
    [nil, 'synthetic_test'].product([[], ['--fix']]).each do |github_action, options|
      assert_annotation_counts("$values = [\n      'first',\n      'second',\n]\n$other = [1] + [2]\n", github_action,
                               options)
    end
  end

  def assert_annotation_counts(code, github_action, options)
    write_source(code, path: 'project_layout.pp')
    assert_cli_failure(*options, @file, env: { 'GITHUB_ACTION' => github_action })
    { 'project_layout' => 2, 'project_arrays' => 1 }.each do |check, count|
      assert_equal count, diagnostics(@output, check).length, @output
    end
    assert_equal annotation_count(github_action, options), @output.lines.grep(/\A::warning /).length, @output
    assert_equal options.empty? ? code : code.gsub('      ', '  '), source
  end

  def annotation_count(github_action, options)
    return 0 unless github_action

    options.empty? ? 3 : 1
  end

  def test_puppet_source_ignore_keeps_the_additional_check_active_with_fix
    %w[files invalid].each { |mount| assert_source_mount(mount) }
  end

  def assert_source_mount(mount)
    code = "$source = 'puppet:///#{mount}/example/app.tar.gz' # lint:ignore:puppet_url_without_modules\n"
    write_source(code, path: 'source.pp')
    assert_cli_result(mount != 'invalid', '--fix', @file)
    assert_includes @output, 'project_puppet_urls' if mount == 'invalid'
    assert_equal code, source
  end

  def test_invalid_puppet_is_an_error_without_a_custom_execution_layer
    [[], ['--fix']].each do |options|
      code = "class example (String $value = ) { $other = \"value\" }\n"
      write_source(code, path: 'broken.pp')
      assert_cli_failure(*options, @file)
      assert_includes @output, 'Invalid Puppet syntax'
      assert_includes @output, ': syntax: error:'
      assert_equal code, source
    end
  end

  def test_clean_numeric_exit_code_and_output_channels_match_the_guide
    write_source("$values = concat([1], [2])\n")
    assert_cli_success(@file)
    assert_equal 0, @status.exitstatus
    assert_empty @output
    assert_empty @errors
  end

  def test_warning_and_error_numeric_exit_codes_match_the_guide
    { "$values = [1] + [2]\n" => 'project_arrays: warning:',
      "# lint:ignore:project_arrays\n$values = [1] + [2]\n# lint:endignore\n" => 'project_suppressions: error:' }
      .each do |code, message|
      write_source(code)
      assert_cli_failure(@file)
      assert_equal 1, @status.exitstatus
      assert_includes @output, message
      assert_empty @errors
    end
  end

  def test_invalid_option_exit_code_and_channels_match_the_guide
    write_source("$values = concat([1], [2])\n")
    assert_cli_failure('--invalid-synthetic-option', @file)
    assert_equal 1, @status.exitstatus
    assert_includes @output, 'invalid option'
    assert_empty @errors
  end

  def test_filtering_output_does_not_change_the_warning_exit_status
    write_source("$values = [1] + [2]\n")
    assert_cli_failure('--error-level', 'error', '--json', @file)
    assert_equal 1, @status.exitstatus
    assert_equal [[]], JSON.parse(@output)
  end

  def test_native_report_write_errors_fail_after_scanning
    write_source("$values = concat([1], [2])\n")
    assert_cli_failure('--json', '--codeclimate-report-file', @directory, @file)
    assert_equal 1, @status.exitstatus
    assert_equal [[]], JSON.parse(@output)
    assert_includes @errors, 'EISDIR'
  end
end
