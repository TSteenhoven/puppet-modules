# frozen_string_literal: true

require_relative 'autofix_test_case'

# Verify cross check autofix behavior through the native linter.
class CrossCheckAutofixTest < AutofixTestCase
  def test_all_checks_fix_the_same_region_in_one_pass
    assert_fix(fixture(:sample),
               fixture(:sample2))
    assert_fix(fixture(:sample3),
               fixture(:sample4))
    assert_fix(fixture(:sample5),
               fixture(:sample6))
  end

  def test_repeated_indentation_fixes_handle_empty_whitespace_tokens
    assert_fix(fixture(:sample),
               fixture(:sample2))
  end

  def test_documentation_and_comment_spacing_share_the_surviving_anchor
    before = fixture(:before)
    after = fixture(:after)
    assert_fix(before, after, :project_documentation_layout, :project_comment_spacing)
  end

  def test_upstream_whitespace_and_custom_alignment_share_live_tokens
    assert_fix(fixture(:sample),
               fixture(:sample2),
               :hard_tabs, :project_layout, :project_parameter_alignment)
  end

  def test_type_width_changes_keep_previously_correct_parameter_alignment
    assert_fix(fixture(:sample),
               fixture(:sample2),
               :project_layout, :project_parameter_alignment)
    assert_fix(fixture(:sample3),
               fixture(:sample4),
               :double_quoted_strings, :project_parameter_alignment)
  end

  def test_removed_upstream_quote_tokens_do_not_break_spacing_anchors
    assert_fix(fixture(:sample),
               fixture(:sample2),
               :only_variable_string, :project_layout, :project_parameter_alignment)
    assert_fix("$values = [\n      \"${value}\",\n]\n",
               "$values = [\n  $value,\n]\n", :only_variable_string, :project_layout)
    assert_fix("$values = ['a',\"${value}\"]\n",
               "$values = ['a', $value]\n", :only_variable_string, :project_layout)
  end

  def test_array_baseline_accounts_for_upstream_tab_expansion
    assert_fix(fixture(:sample),
               fixture(:sample2), :hard_tabs, :project_layout)
  end
end
