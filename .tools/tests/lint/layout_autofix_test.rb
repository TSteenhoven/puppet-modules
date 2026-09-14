# frozen_string_literal: true

require_relative 'autofix_test_case'

# Verify layout autofix behavior through the native linter.
class LayoutAutofixTest < AutofixTestCase
  def test_comment_spacing_preserves_comments_and_indentation
    assert_fix(fixture(:sample),
               fixture(:sample2), :project_comment_spacing)
    assert_fix(fixture(:sample3),
               fixture(:sample4), :project_comment_spacing)
  end

  def test_layout_fixes_commas_blank_lines_and_nested_arrays
    assert_fix(fixture(:sample),
               fixture(:sample2), :project_layout)
  end

  def test_layout_parameter_trailing_comma_and_nested_default
    assert_fix(fixture(:sample),
               fixture(:sample2), :project_layout)
  end

  def test_array_resource_titles_use_the_resource_level
    assert_fix(fixture(:sample),
               fixture(:sample2), :project_layout)
  end

  def test_parameter_alignment_uses_the_whole_block
    assert_fix(fixture(:sample),
               fixture(:sample2), :project_parameter_alignment)
  end

  def test_parameter_alignment_with_multiline_types_and_defaults
    assert_fix(fixture(:sample),
               fixture(:sample2), :project_parameter_alignment)
  end

  def test_parameter_alignment_does_not_move_comments_or_inline_parameters
    [fixture(:sample),
     fixture(:sample2)].each do |code|
      problems, fixed = lint_checks(code, [:project_parameter_alignment], fix: true)
      refute_empty problems
      assert(problems.all? { |problem| problem[:kind] == :warning })
      assert_equal code, fixed
    end
  end

  def test_ignored_findings_are_never_fixed
    {
      project_comment_spacing: "$a = 1\n# Explain b.\n$b = 2\n",
      project_layout: "$a = [1,2]\n",
      project_parameter_alignment: fixture(:sample),
      project_resource_references: fixture(:sample2),
      project_documentation_layout: fixture(:sample3)
    }.each do |rule, body|
      assert_ignored_fix(rule, body)
    end
  end

  def test_partial_suppression_prevents_edits_across_the_ignored_region
    code = fixture(:code)
    problems, fixed = lint_checks(code, [:project_parameter_alignment], fix: true)
    refute_empty problems
    assert_equal code, fixed
    code = fixture(:code2)
    problems, fixed = lint_checks(code, [:project_resource_references], fix: true)
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_equal code, fixed
  end

  def test_literal_contents_and_correct_code_remain_unchanged
    code = fixture(:code)
    problems, fixed = lint_checks(code, %i[project_layout project_comment_spacing], fix: true)
    assert_empty problems
    assert_equal code, fixed
  end

  def test_layout_does_not_move_comments_between_comma_and_value
    code = fixture(:code)
    problems, fixed = lint_checks(code, [:project_layout], fix: true)
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_equal code, fixed
  end

  def test_heredoc_parameter_endings_remain_manual_without_changing_the_body
    code = fixture(:code)
    problems, fixed = lint_checks(code, [:project_layout], fix: true)
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_equal code, fixed
    assert_equal code, lint_checks(fixed, [:project_layout], fix: true).last
  end

  def assert_ignored_fix(rule, body)
    code = "# lint:ignore:#{rule}\n#{body}# lint:endignore\n"
    problems, fixed = lint_checks(code, [rule], fix: true)
    refute_empty problems, rule.to_s
    assert problems.all? { |problem| problem[:kind] == :ignored }, problems.inspect
    assert_equal code, fixed
  end
end
