# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'

# Verify parameter forwarding through the packaged check in an independent consumer.
class ExternalParameterPassthroughTest < Minitest::Test
  include InstalledGemSupport

  def test_installed_check_rejects_indirect_forwarding_and_preserves_source
    write('modules/example/manifests/task.pp', 'define example::task (Integer $value = 7) {}')
    code = "$original = 7\n$source = $original\n" \
           "$settings = { 'value' => $source }.filter |$key, $item| { $item != 7 }\n" \
           "example::task { 'synthetic': * => $settings }\n"
    write('manifests/site.pp', code)
    lint('--fix', '--only-checks=project_parameter_passthrough', 'manifests')
    refute @status.success?, @output + @errors
    assert_includes @output, 'project_parameter_passthrough: warning: [review]'
    assert_equal code, read('manifests/site.pp')
  end

  def test_installed_check_accepts_direct_attributes
    write('manifests/site.pp', "example::task { 'synthetic': value => $value }\n")
    lint('--only-checks=project_parameter_passthrough', 'manifests')
    assert @status.success?, @output + @errors
    assert_empty @output
  end

  def test_installed_check_keeps_a_functional_filter_with_equal_parameter_names
    write('modules/example/manifests/task.pp', 'define example::task (Integer $value = 7) {}')
    write('manifests/site.pp', "$value = 0\n" \
                               "$settings = { 'value' => $value }.filter |$key, $item| { $item != 0 }\n" \
                               "example::task { 'synthetic': * => $settings }\n")
    lint('--only-checks=project_parameter_passthrough', 'manifests')
    assert @status.success?, @output + @errors
    assert_empty @output
  end

  def test_receiving_defaults_follow_modulepath_precedence
    write('modules/example/manifests/task.pp', 'define example::task (Integer $value = 7) {}')
    write('dependencies/example/manifests/task.pp', 'define example::task (Integer $value = 9) {}')
    write('manifests/site.pp', "$source = 7\n" \
                               "$settings = { 'value' => $source }.filter |$key, $item| { $item != 7 }\n" \
                               "example::task { 'synthetic': * => $settings }\n")
    lint('--only-checks=project_parameter_passthrough', 'manifests')
    refute @status.success?, @output + @errors
    reverse_modulepath
    lint('--only-checks=project_parameter_passthrough', 'manifests')
    assert @status.success?, @output + @errors
  end

  def test_local_receiving_definition_precedes_the_modulepath
    write('modules/example/manifests/task.pp', 'define example::task (Integer $value = 7) {}')
    write('manifests/site.pp', "define example::task (Integer $value = 9) {}\n" \
                               "$source = 7\n" \
                               "$settings = { 'value' => $source }.filter |$key, $item| { $item != 7 }\n" \
                               "example::task { 'synthetic': * => $settings }\n")
    lint('--only-checks=project_parameter_passthrough', 'manifests')
    assert @status.success?, @output + @errors
  end
end
