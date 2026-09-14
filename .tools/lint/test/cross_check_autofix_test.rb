# frozen_string_literal: true

require_relative 'test_helper'

# Verify cross check autofix behavior through the native linter.
class CrossCheckAutofixTest < Minitest::Test
  include LintTestSupport

  def test_all_checks_fix_the_same_region_in_one_pass
    assert_fix("Notify['target'] -> [\n      File[\"/z\"],File[\"/a\"]\n]\n",
               "Notify['target'] -> File['/a', '/z']\n")
    assert_fix(fixture('cross_check_autofix/region_in_one_pass_sample3'),
               "Notify['target'] -> [\n  Package['a', 'z'],\n  Service['a', 'z'],\n]\n")
    assert_fix("Notify['target'] -> [Package[\"z\",\"b\"],Service[\"nginx\"],Package[\"a\",\"a\"]]\n",
               "Notify['target'] -> [Package['a', 'a', 'b', 'z'], Service['nginx']]\n")
  end

  def test_repeated_indentation_fixes_handle_empty_whitespace_tokens
    assert_fix("$command = join([\n      'first',\n      'second',\n    ], ' ')\n",
               "$command = join([\n  'first',\n  'second',\n], ' ')\n")
  end

  def test_documentation_and_comment_spacing_share_the_surviving_anchor
    before = fixture('cross_check_autofix/share_the_surviving_anchor_before')
    after = fixture('cross_check_autofix/share_the_surviving_anchor_after')
    assert_fix(before, after, :project_documentation_layout, :project_comment_spacing)
  end

  def test_upstream_whitespace_and_custom_alignment_share_live_tokens
    assert_fix("class example (\n\tEnum['a','b'] $a = 'a',\n  String $long=  'b'\n) {}\n",
               "class example (\n  Enum['a', 'b'] $a    = 'a',\n  String         $long = 'b',\n) {}\n",
               :hard_tabs, :project_layout, :project_parameter_alignment)
  end

  def test_type_width_changes_keep_previously_correct_parameter_alignment
    assert_fix("class example (\n  Enum['a','b'] $a = 'a',\n  String        $b = 'b',\n) {}\n",
               "class example (\n  Enum['a', 'b'] $a = 'a',\n  String         $b = 'b',\n) {}\n",
               :project_layout, :project_parameter_alignment)
    assert_fix("class example (\n  Enum[\"a\", \"b\"] $a = 'a',\n  String         $b = 'b',\n) {}\n",
               "class example (\n  Enum['a', 'b'] $a = 'a',\n  String         $b = 'b',\n) {}\n",
               :double_quoted_strings, :project_parameter_alignment)
  end

  def test_removed_upstream_quote_tokens_do_not_break_spacing_anchors
    assert_fix("class example (\n  String $a= \"${value}\"\n) {}\n",
               "class example (\n  String $a = $value,\n) {}\n",
               :only_variable_string, :project_layout, :project_parameter_alignment)
    assert_fix("$values = [\n      \"${value}\",\n]\n",
               "$values = [\n  $value,\n]\n", :only_variable_string, :project_layout)
    assert_fix("$values = ['a',\"${value}\"]\n",
               "$values = ['a', $value]\n", :only_variable_string, :project_layout)
  end

  def test_array_baseline_accounts_for_upstream_tab_expansion
    assert_fix("if $active {\n\t$values = [\n   'a',\n ]\n}\n",
               "if $active {\n  $values = [\n    'a',\n  ]\n}\n", :hard_tabs, :project_layout)
  end
end
