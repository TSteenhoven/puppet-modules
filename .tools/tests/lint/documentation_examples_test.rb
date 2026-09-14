# frozen_string_literal: true

require_relative 'documentation_test_case'

# Verify documentation examples behavior through the native linter.
class DocumentationExamplesTest < DocumentationTestCase
  def test_nested_example_code_and_blank_lines_remain_exact
    body = fixture(:body)
    assert_clean(document(body))
  end

  def test_example_code_is_never_wrapped_as_prose
    body = "# @example Configure the class\n#   notice('#{'word ' * 26}')\n"
    code = document(body)
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_includes problems.first[:message], '[review]'
  end

  def test_example_indentation_requires_manual_review
    code = document(fixture(:code))
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_includes problems.first[:message], 'indented with two spaces'
  end

  def test_example_title_body_and_initial_indentation_are_required
    ["# @example\n#   include example\n", "# @example Include the class\n",
     fixture(:sample)].each do |body|
      code = document(body)
      problems, fixed = lint(code, fix: true)
      assert_equal code, fixed
      refute_empty problems
      assert(problems.all? { |problem| problem[:kind] == :warning })
    end
  end
end
