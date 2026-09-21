# frozen_string_literal: true

require_relative 'test_helper'

# Verify native diagnostics, exit status and source preservation for parameter forwarding.
class CliParameterPassthroughTest < Minitest::Test
  include LintCliSupport

  def test_forwarding_fails_without_an_unsafe_fix
    code = "define example::task (Integer $value = 7) {}\n" \
           "$source = 7\n" \
           "$settings = { 'value' => $source }.filter |$key, $item| { $item != 7 }\n" \
           "example::task { 'synthetic': * => $settings }\n"
    options = ['--only-checks=project_parameter_passthrough']
    write_source(code)
    assert_cli_failure(*options, @file)
    assert_includes @output, ':3:15: project_parameter_passthrough: warning: [review]'
    assert_equal code, source
    assert_review_source(code, 'project_parameter_passthrough', options: options)
  end

  def test_direct_attributes_pass
    direct = "example::task { 'synthetic': value => $value }\n"
    write_source(direct)
    assert_cli_stable(direct, '--only-checks=project_parameter_passthrough')
  end

  def mixed_forwarding
    <<~PUPPET
      define example::task (Integer $value = 2, Integer $other = 7) {}
      $source = 2
      $other = 0
      $settings = {
        'value' => $source,
        'other' => $other,
      }.filter |$key, $item| { $item != 0 }
      example::task { 'synthetic': * => $settings }
    PUPPET
  end

  def test_only_the_redundant_key_is_reported
    code = mixed_forwarding
    options = ['--only-checks=project_parameter_passthrough']
    write_source(code)
    assert_cli_failure(*options, @file)
    assert_includes @output, ':5:3: project_parameter_passthrough: warning: [review]'
    assert_equal 1, @output.scan('project_parameter_passthrough: warning:').size
    assert_review_source(code, 'project_parameter_passthrough', options: options)
  end

  def test_direct_forwarding_of_the_redundant_key_preserves_the_useful_filter
    direct = mixed_forwarding.sub("  'value' => $source,\n", '')
    direct = direct.sub('* => $settings', 'value => $source, * => $settings')
    write_source(direct)
    assert_cli_stable(direct, '--only-checks=project_parameter_passthrough')
  end

  def test_functional_filters_pass_with_fix_without_changing_source
    code = "define example::task (Integer $value = 7) {}\n" \
           "$value = 0\n" \
           "$settings = { 'value' => $value }.filter |$key, $item| { $item != 0 }\n" \
           "example::task { 'synthetic': * => $settings }\n"
    write_source(code)
    assert_cli_stable(code, '--only-checks=project_parameter_passthrough')
  end
end
