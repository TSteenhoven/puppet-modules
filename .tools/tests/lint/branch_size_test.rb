# frozen_string_literal: true

require_relative 'check_test_case'

# Verify the branch size contract with native lint diagnostics.
class BranchSizeTest < CheckTestCase
  def test_positive_flow_keeps_guards_without_else_and_equally_small_branches
    assert_empty findings("if !defined(Package['example']) { package { 'example': } }", 'project_positive_flow')
    assert_empty findings("if $active { $value = 'first' } else { $value = 'second' }", 'project_positive_flow')
    assert_empty findings(fixture(:sample), 'project_positive_flow')
  end

  def test_positive_flow_rejects_short_assignments_before_the_larger_else
    code = fixture(:code)
    assert_equal([[1, :warning]], findings(code, 'project_positive_flow').map do |problem|
      problem.values_at(:line, :kind)
    end)
    reversed = fixture(:reversed)
    assert_empty findings(reversed, 'project_positive_flow')
  end

  def test_positive_flow_handles_all_short_calls_through_the_same_structure_rule
    %w[fail warning notice custom::report_issue].each do |function|
      code = "if $missing { #{function}('Synthetic message') } else { file { '/tmp/example': } }"
      problems = findings(code, 'project_positive_flow')
      assert_equal [:warning], problems.map { |problem| problem[:kind] }, function
      assert_equal problems.first[:message],
                   findings(code.sub(function, 'notice'), 'project_positive_flow').first[:message]
    end
    code = fixture(:code)
    assert_equal([:warning], finding_kinds(code, 'project_positive_flow'))
  end

  def test_positive_flow_counts_nested_work_inside_single_top_level_statements
    bodies = fixture(:bodies)
    bodies.each do |body|
      code = "if $absent { $one = undef; $two = undef } else { #{body} }"
      assert_equal [:warning], finding_kinds(code, 'project_positive_flow'), body
    end
  end

  def test_positive_flow_counts_structured_values_without_counting_scalar_text
    ["{ 'one' => 1, 'two' => 2 }", "['one', 'two']", "$kind ? { 'one' => 1, default => 2 }"].each do |value|
      code = "if $absent { $settings = undef } else { $settings = #{value} }"
      assert_equal [:warning], finding_kinds(code, 'project_positive_flow'), value
    end
    assert_empty findings(fixture(:sample), 'project_positive_flow')
    code = fixture(:code)
    assert_equal([:warning], finding_kinds(code, 'project_positive_flow'))
  end

  def test_positive_flow_ignores_comments_whitespace_and_physical_line_count
    code = fixture(:code)
    assert_equal([[1, :warning]], findings(code, 'project_positive_flow').map do |problem|
      problem.values_at(:line, :kind)
    end)
    assert_equal([:warning], finding_kinds(code.gsub("\n", "\r\n"), 'project_positive_flow'))
    assert_empty findings("$content = 'if $absent { short } else { long }'", 'project_positive_flow')
  end

  def test_positive_flow_compares_individual_elsif_arms_and_retains_priority_requirements
    valid = fixture(:valid)
    assert_empty findings(valid, 'project_positive_flow')
    reversed = 'if $first { $one = 1 } elsif $second { $one = 2; $two = 3 } else { $one = 4 }'
    assert_equal([:warning], finding_kinds(reversed, 'project_positive_flow'))
    final_else = fixture(:final_else)
    problems = findings(final_else, 'project_positive_flow')
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_includes problems.first[:message], 'elsif priority'
    assert_empty findings('if $first { $one = 1; $two = 2 } elsif $second { $one = 3 }', 'project_positive_flow')
  end

  def test_positive_flow_treats_an_explicit_nested_if_as_nested_work
    code = fixture(:code)
    assert_equal([:warning], finding_kinds(code, 'project_positive_flow'))
  end

  def test_positive_flow_applies_the_same_branch_order_to_unless
    assert_equal([:warning],
                 finding_kinds('unless $active { $value = undef } else { $one = 1; $two = 2 }',
                               'project_positive_flow'))
    assert_empty findings('unless $active { $one = 1; $two = 2 } else { $value = undef }', 'project_positive_flow')
  end
end
