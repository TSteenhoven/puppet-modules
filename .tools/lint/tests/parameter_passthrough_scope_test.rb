# frozen_string_literal: true

require_relative 'test_helper'

# Limit forwarding analysis to unambiguous local bindings available at the resource declaration.
class ParameterPassthroughScopeTest < Minitest::Test
  include LintTestSupport

  RULE = :project_parameter_passthrough

  def test_prior_assignment_is_visible_in_its_own_or_a_nested_branch
    code = <<~PUPPET
      define example::wrapper {
        if $enabled {
          $settings = { 'value' => $value }
          if $nested { example::task { 'synthetic': * => $settings } }
        }
      }
    PUPPET
    assert_equal [:warning], finding_kinds(code)
  end

  def test_assignments_in_other_scopes_or_branches_do_not_supply_the_splat
    snippets = [
      "class owner { $settings = { 'value' => $value } }\nexample::task { 'synthetic': * => $settings }",
      "if $enabled { $settings = { 'value' => $value } }\nexample::task { 'synthetic': * => $settings }",
      "example::task { 'synthetic': * => $settings }\n$settings = { 'value' => $value }",
      "$settings = { 'value' => $value }\n$settings = lookup('settings')\n" \
      "example::task { 'synthetic': * => $settings }"
    ]
    snippets.each { |code| assert_clean_passes(code) }
  end

  def test_lambda_arguments_shadow_an_outer_assignment
    code = <<~PUPPET
      $settings = { 'value' => $value }
      $items.each |$settings| { example::task { 'synthetic': * => $settings } }
    PUPPET
    assert_clean_passes(code)
  end

  def test_local_assignment_inside_a_lambda
    code = <<~PUPPET
      $items.each |$value| {
        $settings = { 'value' => $value }
        example::task { 'synthetic': * => $settings }
      }
    PUPPET
    assert_equal [:warning], finding_kinds(code)
  end
end
