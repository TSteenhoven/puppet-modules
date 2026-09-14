# frozen_string_literal: true

require_relative 'test_helper'

# Verify layout autofix behavior through the native linter.
class LayoutAutofixTest < Minitest::Test
  include LintTestSupport

  def test_comment_spacing_preserves_comments_and_indentation
    assert_fix("$a = 1\n# Explain b.\n$b = 2\n# Explain c.\n$c = 3\n",
               fixture('layout_autofix/preserves_comments_and_indentation_sample2'), :project_comment_spacing)
    assert_fix("if $active {\n  $a = 1\n  /* Explain b. */\n  $b = 2\n}\n",
               fixture('layout_autofix/preserves_comments_and_indentation_sample4'), :project_comment_spacing)
  end

  def test_layout_fixes_commas_blank_lines_and_nested_arrays
    before = "$values = [\n      [\n        'a','b',\n      ],\n]\n" \
             "if $active { # Explain.\n\n \t\n  notice('Active')\n}\n"
    assert_fix(before, fixture('layout_autofix/lines_and_nested_arrays_sample2'), :project_layout)
  end

  def test_layout_parameter_trailing_comma_and_nested_default
    assert_fix("class example (\n  Array[String] $items = concat(['a','b'], ['c']) # Keep this reason.\n) {}\n",
               fixture('layout_autofix/comma_and_nested_default_sample2'), :project_layout)
  end

  def test_array_resource_titles_use_the_resource_level
    assert_fix(fixture('layout_autofix/use_the_resource_level_sample'),
               fixture('layout_autofix/use_the_resource_level_sample2'), :project_layout)
  end

  def test_parameter_alignment_uses_the_whole_block
    assert_fix(fixture('layout_autofix/uses_the_whole_block_sample'),
               fixture('layout_autofix/uses_the_whole_block_sample2'), :project_parameter_alignment)
  end

  def test_parameter_alignment_with_multiline_types_and_defaults
    assert_fix(fixture('layout_autofix/multiline_types_and_defaults_sample'),
               fixture('layout_autofix/multiline_types_and_defaults_sample2'), :project_parameter_alignment)
  end

  def test_parameter_alignment_does_not_move_comments_or_inline_parameters
    ["class example (String $a, String $long = 'value') {}\n",
     "class example (\n  String /* Type explanation. */ $a = 'a',\n  String $long = 'b',\n) {}\n"].each do |code|
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
      project_parameter_alignment: "class example (\n  String $a = 'a',\n  Optional[String] $long = undef,\n) {}\n",
      project_resource_references: "Notify['target'] -> [File['/z'], File['/a']]\n",
      project_documentation_layout: "# @summary Example.\n# @api public\nclass example {}\n"
    }.each do |rule, body|
      assert_ignored_fix(rule, body)
    end
  end

  def test_partial_suppression_prevents_edits_across_the_ignored_region
    code = fixture('layout_autofix/across_the_ignored_region_code')
    problems, fixed = lint_checks(code, [:project_parameter_alignment], fix: true)
    refute_empty problems
    assert_equal code, fixed
    code = "Notify['target'] -> File[\n  '/z',\n  '/a', # lint:ignore:project_resource_references\n]\n"
    problems, fixed = lint_checks(code, [:project_resource_references], fix: true)
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_equal code, fixed
  end

  def test_literal_contents_and_correct_code_remain_unchanged
    code = fixture('layout_autofix/correct_code_remain_unchanged_code')
    problems, fixed = lint_checks(code, %i[project_layout project_comment_spacing], fix: true)
    assert_empty problems
    assert_equal code, fixed
  end

  def test_layout_does_not_move_comments_between_comma_and_value
    code = "$values = [1,/* Keep this reason. */2]\n"
    problems, fixed = lint_checks(code, [:project_layout], fix: true)
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_equal code, fixed
  end

  def test_heredoc_parameter_endings_remain_manual_without_changing_the_body
    code = fixture('layout_autofix/without_changing_the_body_code')
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
