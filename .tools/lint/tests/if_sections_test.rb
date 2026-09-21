# frozen_string_literal: true

require_relative 'test_helper'

# Verify the if sections contract with native lint diagnostics.
class IfSectionsTest < Minitest::Test
  include LintTestSupport

  def test_if_sections_require_an_explanation_for_standalone_conditions
    code = "if (defined(Class['nginx'])) { notice('Available') }\n"
    assert_equal([[1, 1]], findings(code, 'project_if_sections').map { |problem| problem.values_at(:line, :column) })
    assert_empty findings("# Require the parent before configuring its resources.\n#{code}", 'project_if_sections')
    assert_empty findings("# Require the parent before configuring its resources.\n\n#{code}", 'project_if_sections')
  end

  def test_if_sections_place_the_explanation_above_transitive_condition_inputs
    code = fixture('if_sections/above_transitive_condition_inputs_code')
    assert_equal([[1, 1]], findings(code, 'project_if_sections').map { |problem| problem.values_at(:line, :column) })
    assert_empty findings("# Validate registration settings only when this backend is active.\n#{code}",
                          'project_if_sections')
    misplaced = code.sub('if (', "# Validate the registration.\nif (")
    assert_equal([1], finding_lines(misplaced, 'project_if_sections'))
  end

  def test_if_sections_follow_multiple_condition_inputs_and_destructuring
    code = "[$minimum, $maximum] = [1, 10]\n$valid = $minimum < $maximum\nif $valid { notice('Valid') }\n"
    assert_equal([1], finding_lines(code, 'project_if_sections'))
    assert_empty findings("# Validate the allowed range before using it.\n#{code}", 'project_if_sections')
    separate = "$minimum = 1\n$maximum = 10\nif $minimum < $maximum { notice('Valid') }\n"
    assert_equal([1], finding_lines(separate, 'project_if_sections'))
  end

  def test_if_sections_do_not_reuse_comments_across_unrelated_work
    prefix = "# Derive the active state.\n$first = true\n$active = $first\n"
    ["$unrelated = 30\n", "notice('Preparation finished')\n", "notify { 'ready': }\n"].each do |separator|
      code = "#{prefix}#{separator}if $active { notice('Active') }\n"
      assert_equal [5], finding_lines(code, 'project_if_sections'), separator
      assert_empty findings(code.sub('if $active', "# Perform the active operation.\nif $active"),
                            'project_if_sections')
    end
  end

  def test_if_sections_do_not_reuse_a_parent_or_previous_condition_explanation
    code = fixture('if_sections/or_previous_condition_explanation_code')
    assert_equal([3, 5, 7], finding_lines(code, 'project_if_sections'))
    assert_equal([2],
                 finding_lines("# Explain the class.\nclass example { if $active { notice('Active') } }",
                               'project_if_sections'))
  end

  def test_if_sections_keep_elsif_in_the_same_chain_and_cover_unless
    code = "# Select the first applicable mode.\nif $first { notice('First') } elsif " \
           "$second { notice('Second') } else { notice('Fallback') }\n"
    assert_empty findings(code, 'project_if_sections')
    assert_equal([:warning], finding_kinds(code.lines.drop(1).join, 'project_if_sections'))
    assert_equal([:warning], finding_kinds("unless $active { notice('Disabled') }", 'project_if_sections'))
    assert_empty findings("# Report disabled operation.\nunless $active { notice('Disabled') }", 'project_if_sections')
    prepared = fixture('if_sections/chain_and_cover_unless_prepared')
    assert_empty findings(prepared, 'project_if_sections')
  end

  def test_if_sections_require_real_comments_and_reuse_existing_spacing
    body = "if $active { notice('Active') }\n"
    ["#\n", "# lint:ignore:140chars\n# lint:endignore\n", "$label = '# A literal comment'\n",
     "$label = 'label' # Trailing comment.\n"].each do |prefix|
      assert_equal [:warning], finding_kinds(prefix + body, 'project_if_sections'), prefix
    end
    assert_empty findings("/* Explain the selected operation. */\n#{body}", 'project_if_sections')
    assert_empty findings("# lint:ignore:140chars\n# Explain the operation.\n# lint:endignore\n#{body}",
                          'project_if_sections')
    assert_comment_spacing_is_independent(body)
  end

  def test_if_sections_respect_lambda_scope_in_condition_dependencies
    code = "# Prepare the outer value.\n$active = true\nif [true].any |$active| { $active } { notice('Active') }\n"
    assert_equal([3], finding_lines(code, 'project_if_sections'))
    assert_empty findings(code.sub('|$active|', '|$item|'), 'project_if_sections')
  end

  def test_if_sections_accept_an_explanation_above_an_assigned_if_expression
    code = "$label = if $active { 'active' } else { 'inactive' }\n"
    assert_equal([[1, 1]], findings(code, 'project_if_sections').map { |problem| problem.values_at(:line, :column) })
    assert_empty findings("# Select the label for the current state.\n#{code}", 'project_if_sections')
  end

  def test_if_sections_handle_multiline_conditions_crlf_and_literal_if_text
    code = "# Check the caf\u00E9 label.\n$label = 'caf\u00E9'\nif (\n  $label != ''\n) { notice($label) }\n"
    assert_empty findings(code, 'project_if_sections')
    assert_empty findings(code.gsub("\n", "\r\n"), 'project_if_sections')
    assert_empty findings("$label = 'if $active { # literal }'", 'project_if_sections')
  end

  def assert_comment_spacing_is_independent(body)
    code = "$label = 'label'\n# Explain the operation.\n#{body}"
    assert_empty findings(code, 'project_if_sections')
    assert_equal([:warning], finding_kinds(code, 'project_comment_spacing'))
  end
end
