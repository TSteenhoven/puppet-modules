# frozen_string_literal: true

require_relative 'test_helper'

# Keep required explanations under manual control while applying safe spacing fixes.
class CliSectionsTest < Minitest::Test
  include LintCliSupport

  def test_section_checks_fail_without_inventing_comments_with_fix
    code = fixture('cli_sections/inventing_comments_with_fix_code')
    write_source(code, path: 'sections.pp')
    assert_cli_failure('--fix', @file)
    assert_includes @output, 'project_comment_spacing'
    assert_includes @output, 'project_resource_sections'
    assert_equal code.sub("$enabled = true\n", "$enabled = true\n\n"), source
  end

  def test_variable_sections_fail_without_inventing_an_explanation_with_fix
    assert_review_source(fixture('cli_sections/an_explanation_with_fix_code'), 'project_variable_sections')
  end

  def test_if_sections_fail_without_inventing_or_moving_comments_with_fix
    ["if $active { notice('Active') }\n", fixture('cli_sections/moving_comments_with_fix_codes2_2')].each do |code|
      assert_review_source(code, 'project_if_sections')
      write_source("# Explain the operation and its prerequisites.\n#{code}")
      assert_cli_success(@file)
    end
  end

  def test_block_variable_sections_offer_a_review_hint_without_moving_assignments_with_fix
    code = fixture('cli_sections/moving_assignments_with_fix_code')
    assert_review_source(code, 'project_variable_sections')
    assert_includes @output, 'section at line 5'
    assert_includes @output, 'checking purpose and evaluation order'
    replacement = "  # Escape the configuration path and check limits.\n  $config_shell = " \
                  'stdlib::shell_escape($config)'
    corrected = code.sub("  $config_shell = stdlib::shell_escape($config)\n\n", '')
                    .sub('  # Escape the check limits.', replacement)
    write_source(corrected)
    assert_cli_success(@file)
  end
end
