# frozen_string_literal: true

require_relative 'test_helper'

# Verify forwarding diagnostics without confusing configuration data or transformations.
class ParameterPassthroughTest < Minitest::Test
  include LintTestSupport

  RULE = :project_parameter_passthrough

  def test_named_hash_forwarding_reports_the_resource_splat
    code = <<~PUPPET
      $settings = { 'schedule' => $schedule, retention => $retention }
      example::task { 'synthetic':
        * => $settings,
      }
    PUPPET
    assert_equal([[3, 3]], findings(code).map { |problem| problem.values_at(:line, :column) })
    assert_preserved(code, [:warning], review: true)
  end

  def test_filtered_forwarding_with_an_unknown_receiver_remains_valid
    code = <<~PUPPET
      $settings = {
        'schedule' => $schedule,
        'retention' => $retention,
      }.filter |$key, $value| { $value != undef }
      example::task { 'synthetic': * => $settings }
    PUPPET
    assert_clean_passes(code)
  end

  def test_inline_hashes_parentheses_and_resource_forms
    ['example::task', 'class', 'notify'].each do |type|
      code = "#{type} { 'synthetic': * => ({ 'value' => ($value) }) }"
      assert_equal [:warning], finding_kinds(code)
    end
  end

  def test_filter_at_the_resource_and_nested_functional_filters_remain_valid
    code = <<~PUPPET
      $settings = { 'value' => $value }.filter |$key, $item| { $item != undef }
      example::task { 'synthetic': * => ($settings).filter |$key, $item| { $enabled } }
    PUPPET
    assert_clean_passes(code)
  end

  def test_each_resource_gets_its_own_diagnostic
    code = <<~PUPPET
      $settings = { 'value' => $value }
      example::task {
        'first': * => $settings;
        'second': * => $settings;
      }
    PUPPET
    assert_equal [3, 4], finding_lines(code)
  end

  def test_direct_attributes_and_config_hashes_remain_valid
    ["example::task { 'synthetic': value => $value }",
     "$settings = { 'value' => $value }\nexample::task { 'synthetic': config => $settings }"].each do |code|
      assert_clean_passes(code)
    end
  end

  def test_hashes_with_actual_mapping_or_computation_remain_valid
    ['{}', "{ 'renamed' => $value }", "{ 'value' => $settings['value'] }",
     "{ 'value' => $value, 'other' => 'literal' }", '{ "${key}" => $key }',
     "{ 'value' => $value + 1 }", "{ 'value' => $owner::value }"].each do |expression|
      assert_clean_passes("example::task { 'synthetic': * => #{expression} }")
    end
  end

  def test_transformations_and_indirect_sources_require_manual_review
    ["lookup('settings')", "merge({ 'value' => $value }, $extra)",
     "{ 'value' => $value }.map |$key, $item| { [$key, $item] }"].each do |expression|
      assert_clean_passes("$settings = #{expression}\nexample::task { 'synthetic': * => $settings }")
    end
    assert_clean_passes("$original = { 'value' => $value }\n$settings = $original\n" \
                        "example::task { 'synthetic': * => $settings }")
  end

  def test_literals_and_comments_do_not_create_forwarding
    code = <<~PUPPET
      # $settings = { 'value' => $value }
      $text = '* => $settings'
      example::task { 'synthetic': * => $settings }
    PUPPET
    assert_clean_passes(code)
  end
end
