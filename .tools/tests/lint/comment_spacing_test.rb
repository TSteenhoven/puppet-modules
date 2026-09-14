# frozen_string_literal: true

require_relative 'check_test_case'

# Verify the comment spacing contract with native lint diagnostics.
class CommentSpacingTest < CheckTestCase
  def test_comment_spacing_between_assignments
    code = fixture(:code)
    problems = findings(code, 'project_comment_spacing')
    assert_equal([[2, 1]], problems.map { |problem| problem.values_at(:line, :column) })
    assert_empty findings(code.sub("\n#", "\n\n#"), 'project_comment_spacing')
    assert_empty findings(code.sub("\n#", "\n \t\n#"), 'project_comment_spacing')
  end

  def test_comment_spacing_preserves_opening_blocks_and_contiguous_comments
    code = fixture(:code)
    assert_empty findings(code, 'project_comment_spacing')
    refute_empty findings(fixture(:sample), 'project_comment_spacing')
  end

  def test_comment_spacing_uses_lexer_comments_not_string_contents
    code = fixture(:code)
    assert_empty findings(code, 'project_comment_spacing')
    assert_empty findings(code, 'project_resource_sections')
  end

  def test_comment_spacing_handles_block_comments_and_lint_metadata
    code = fixture(:code)
    assert_equal([2], finding_lines(code, 'project_comment_spacing'))
    assert_empty findings(code.sub("\n/*", "\n\n/*"), 'project_comment_spacing')
    assert_empty findings(fixture(:sample), 'project_comment_spacing')
    assert_control_spacing(fixture(:wrapped), 2, "\n# lint:ignore", "\n\n# lint:ignore")
    assert_control_spacing(fixture(:closed), 4, "# lint:endignore\n", "# lint:endignore\n\n")
  end

  def assert_control_spacing(code, line, before, after)
    assert_equal [line], finding_lines(code, 'project_comment_spacing')
    assert_empty findings(code.sub(before, after), 'project_comment_spacing')
  end
end
