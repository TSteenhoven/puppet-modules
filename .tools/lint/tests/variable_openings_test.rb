# frozen_string_literal: true

require_relative 'test_helper'

# Verify the variable openings contract with native lint diagnostics.
class VariableOpeningsTest < Minitest::Test
  include LintTestSupport

  BLOCK_OPENINGS = ["class example { $value = 'example' }", "define example { $value = 'example' }",
                    "case $state { default: { $value = 'example' } }",
                    '$items.each |$item| { $value = $item }',
                    'unless $active { [$one, $two] = [1, 2] }'].freeze

  def test_variable_sections_explain_assignments_at_each_block_opening
    code = fixture('variable_openings/at_each_block_opening_code')
    assert_equal([3, 5, 7], finding_lines(code, 'project_variable_sections'))
    corrected = code.gsub('  $value', "  # Prepare the label for this state.\n  $value")
    assert_empty findings(corrected, 'project_variable_sections')
  end

  def test_variable_sections_cover_classes_defines_case_arms_and_lambdas
    BLOCK_OPENINGS.each do |code|
      assert_equal [:warning], finding_kinds(code, 'project_variable_sections'), code
    end
    assert_empty findings("$value = 'example'", 'project_variable_sections')
    assert_empty findings("if $active { notice('Active'); $value = 'example' }", 'project_variable_sections')
    assert_empty findings("$values = { 'first' => 1 }", 'project_variable_sections')
    assert_empty findings("$literal = 'if $active { $value = 1 }'", 'project_variable_sections')
  end

  def test_variable_sections_require_real_internal_comments_without_a_leading_blank_line
    ['', "\n", "#\n", "# lint:ignore:140chars\n# lint:endignore\n"].each do |prefix|
      code = "# Explain the condition.\nif $active {\n#{prefix}  $value = 'example'\n}\n"
      assert_equal [:warning], finding_kinds(code, 'project_variable_sections'), prefix
    end
    ['# Prepare the local label.', '/* Prepare the local label. */'].each do |comment|
      code = "# Explain the condition.\nif $active {\n  #{comment}\n  $value = 'café'\n}\n"
      assert_empty findings(code, 'project_variable_sections')
      assert_empty findings(code, 'project_comment_spacing')
      assert_empty findings(code.gsub("\n", "\r\n"), 'project_variable_sections')
    end
  end

  def test_variable_sections_hint_at_a_later_documented_group_with_the_same_function
    code = fixture('variable_openings/with_the_same_function_code')
    problems = findings(code, 'project_variable_sections')
    assert_equal([2], problems.map { |problem| problem[:line] })
    assert_includes problems.first[:message], 'section at line 9'
    assert_includes problems.first[:message], 'checking purpose and evaluation order'
    renamed = code.gsub('stdlib::shell_escape', 'example::transform')
    assert_includes findings(renamed, 'project_variable_sections').first[:message], 'section at line 9'
  end

  def test_variable_sections_do_not_suggest_moving_past_a_use_or_control_boundary
    ['notice($config_shell)', '$used = $config_shell', "if $other { notice('Other') }"].each do |intervening|
      assert_control_boundary(intervening)
    end
    code = fixture('variable_openings/use_or_control_boundary_code')
    refute_includes findings(code, 'project_variable_sections').first[:message], 'section at line'
    different = fixture('variable_openings/use_or_control_boundary_different')
    refute_includes findings(different, 'project_variable_sections').first[:message], 'section at line'

    # Calls that own lambdas are not simple transformations to regroup.
    assert_lambda_boundaries(different)
  end

  def assert_control_boundary(intervening)
    code = "if $active {\n$config_shell = stdlib::shell_escape($config)\n#{intervening}\n\n" \
           "# Escape the timeout.\n$timeout_shell = stdlib::shell_escape(String($timeout))\n}\n"
    problems = findings(code, 'project_variable_sections')
    assert_equal([2], problems.map { |problem| problem[:line] })
    refute_includes problems.first[:message], 'section at line'
  end

  def assert_lambda_boundaries(code)
    matching = code.sub('String($timeout)', 'stdlib::shell_escape($timeout)')
    ['stdlib::shell_escape($config)', 'stdlib::shell_escape($timeout)'].each do |call|
      with_lambda = matching.sub(call, "#{call} |$item| { $item }")
      refute_includes findings(with_lambda, 'project_variable_sections').first[:message], 'section at line'
    end
  end
end
