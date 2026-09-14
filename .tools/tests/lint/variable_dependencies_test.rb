# frozen_string_literal: true

require_relative 'check_test_case'

# Verify the variable dependencies contract with native lint diagnostics.
class VariableDependenciesTest < CheckTestCase
  def test_variable_sections_split_the_name_group_before_independent_check_settings
    code = fixture(:code)
    assert_equal([[5, 1]], findings(code, 'project_variable_sections').map do |problem|
      problem.values_at(:line, :column)
    end)
    corrected = code.sub("\n$detail_limit_shell", fixture(:corrected))
    assert_empty findings(corrected, 'project_variable_sections')
    assert_empty findings(corrected, 'project_comment_spacing')
  end

  def test_variable_sections_need_an_explanation_and_reuse_comment_spacing
    code = fixture(:code)
    ["\n", "\n\n", " # Explain the label.\n", "\n\n#\n",
     fixture(:sample)].each do |separator|
      changed = code.sub("\n$timeout", "#{separator}$timeout")
      assert_equal [:warning], finding_kinds(changed, 'project_variable_sections'), changed
    end
    unseparated = code.sub("\n$timeout", "\n# Set the timeout.\n$timeout")
    assert_empty findings(unseparated, 'project_variable_sections')
    assert_equal([:warning], finding_kinds(unseparated, 'project_comment_spacing'))
  end

  def test_variable_sections_allow_batches_without_proven_internal_dependencies
    code = fixture(:code)
    assert_empty findings(code, 'project_variable_sections')
    assert_empty findings(fixture(:sample), 'project_variable_sections')
    assert_empty findings(fixture(:sample2), 'project_variable_sections')
  end

  def test_variable_sections_follow_transitive_reads_and_report_once_per_boundary
    code = fixture(:code)
    assert_equal([5, 8], finding_lines(code, 'project_variable_sections'))
  end

  def test_variable_sections_do_not_guess_from_names_comments_or_literal_text
    code = fixture(:code)
    assert_empty findings(code, 'project_variable_sections')
    interpolated = code.sub("'Literal ${seed} text'", '"Literal ${seed} text"')
    assert_equal([4], finding_lines(interpolated, 'project_variable_sections'))
    renamed = interpolated.gsub('seed_timeout', 'unrelated').gsub('seed', 'input')
    assert_equal([4], finding_lines(renamed, 'project_variable_sections'))
  end

  def test_variable_sections_limit_dependency_grouping_to_annotated_sequences
    assert_empty findings(fixture(:sample), 'project_variable_sections')
    code = fixture(:code)
    assert_empty findings(code, 'project_variable_sections')
    code = fixture(:code3)
    assert_equal([4], finding_lines(code, 'project_variable_sections'))
    assert_equal([2], finding_lines(fixture(:sample4), 'project_variable_sections'))
  end

  def test_variable_sections_check_nested_blocks_without_leaking_state
    code = fixture(:code)
    assert_equal [[5, 3], [7, 3], [13, 3]], findings(code, 'project_variable_sections').map { |problem|
      problem.values_at(:line, :column)
    }.sort
  end

  def test_variable_sections_respect_lambda_parameters_and_local_assignments
    code = fixture(:code)
    assert_equal([4], finding_lines(code, 'project_variable_sections'))
    assert_empty findings(code.sub('|$item|', '|$seed|'), 'project_variable_sections')
    assert_empty findings(
      code.sub('{ $seed }',
               fixture(:sample)), 'project_variable_sections'
    )
    nested = code.sub('{ $seed }', '{ [2].map |$seed| { $seed } }')
    assert_empty findings(nested, 'project_variable_sections')
  end

  def test_variable_sections_support_destructuring_and_multiline_expressions
    code = fixture(:code)
    assert_equal([8], finding_lines(code, 'project_variable_sections'))
  end

  def test_variable_sections_handle_block_comments_crlf_and_same_line_assignments
    code = fixture(:code)
    assert_equal([:warning], finding_kinds(code, 'project_variable_sections'))
    assert_equal([:warning], finding_kinds(code.gsub("\n", "\r\n"), 'project_variable_sections'))
    wrapped = fixture(:wrapped)
    assert_equal([6], finding_lines(wrapped, 'project_variable_sections'))
  end
end
