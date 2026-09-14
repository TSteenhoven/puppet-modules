require_relative 'test_helper'

class AutofixTest < Minitest::Test
  include LintTestSupport

  def assert_fix(before, after, *rules)
    rules = nil if rules.empty?
    problems, unchanged = lint_checks(before, rules)
    refute_empty problems
    assert_equal before, unchanged
    problems, fixed = lint_checks(before, rules, fix: true)
    assert problems.any? { |problem| problem[:kind] == :fixed }, problems.inspect
    assert_equal after, fixed
    # This asserts the linter's output contract, not general repository syntax.
    ProjectLint::Model.new(fixed)
    problems, unchanged = lint_checks(fixed, rules)
    assert_empty problems
    assert_equal fixed, unchanged
    problems, second = lint_checks(fixed, rules, fix: true)
    assert_empty problems
    assert_equal fixed, second
  end

  def test_comment_spacing_preserves_comments_and_indentation
    assert_fix("$a = 1\n# Explain b.\n$b = 2\n# Explain c.\n$c = 3\n",
               "$a = 1\n\n# Explain b.\n$b = 2\n\n# Explain c.\n$c = 3\n", :project_comment_spacing)
    assert_fix("if $active {\n  $a = 1\n  /* Explain b. */\n  $b = 2\n}\n",
               "if $active {\n  $a = 1\n\n  /* Explain b. */\n  $b = 2\n}\n", :project_comment_spacing)
  end

  def test_layout_fixes_commas_blank_lines_and_nested_arrays
    assert_fix("$values = [\n      [\n        'a','b',\n      ],\n]\nif $active { # Explain.\n\n \t\n  notice('Active')\n}\n",
               "$values = [\n  [\n    'a', 'b',\n  ],\n]\nif $active { # Explain.\n  notice('Active')\n}\n", :project_layout)
  end

  def test_layout_parameter_trailing_comma_and_nested_default
    assert_fix("class example (\n  Array[String] $items = concat(['a','b'], ['c']) # Keep this reason.\n) {}\n",
               "class example (\n  Array[String] $items = concat(['a', 'b'], ['c']), # Keep this reason.\n) {}\n", :project_layout)
  end

  def test_array_resource_titles_use_the_resource_level
    assert_fix("file { [\n'/tmp/a',\n'/tmp/b',\n]:\n  ensure => absent,\n}\n",
               "file { [\n    '/tmp/a',\n    '/tmp/b',\n  ]:\n  ensure => absent,\n}\n", :project_layout)
  end

  def test_parameter_alignment_uses_the_whole_block
    assert_fix("class example (\n  String $a,\n  Optional[String] $label=  undef,\n  String $longer = 'value',\n) {}\n",
               "class example (\n  String           $a,\n  Optional[String] $label  = undef,\n  String           $longer = 'value',\n) {}\n", :project_parameter_alignment)
  end

  def test_parameter_alignment_with_multiline_types_and_defaults
    assert_fix("define example (\n  Variant[\n    String,\n    Array[String]\n  ] $a = [\n    'value',\n  ],\n  String $long = 'value',\n) {}\n",
               "define example (\n  Variant[\n    String,\n    Array[String]\n  ]      $a    = [\n    'value',\n  ],\n  String $long = 'value',\n) {}\n", :project_parameter_alignment)
  end

  def test_parameter_alignment_does_not_move_comments_or_inline_parameters
    ["class example (String $a, String $long = 'value') {}\n",
     "class example (\n  String /* Type explanation. */ $a = 'a',\n  String $long = 'b',\n) {}\n"].each do |code|
      problems, fixed = lint_checks(code, [:project_parameter_alignment], fix: true)
      refute_empty problems
      assert problems.all? { |problem| problem[:kind] == :warning }
      assert_equal code, fixed
    end
  end

  def test_ignored_findings_are_never_fixed
    {
      project_comment_spacing: "$a = 1\n# Explain b.\n$b = 2\n",
      project_layout: "$a = [1,2]\n",
      project_parameter_alignment: "class example (\n  String $a = 'a',\n  Optional[String] $long = undef,\n) {}\n",
      project_resource_references: "Notify['target'] -> [File['/z'], File['/a']]\n",
      project_documentation_layout: "# @summary Example.\n# @api public\nclass example {}\n",
    }.each do |rule, body|
      code = "# lint:ignore:#{rule}\n#{body}# lint:endignore\n"
      problems, fixed = lint_checks(code, [rule], fix: true)
      refute_empty problems, rule.to_s
      assert problems.all? { |problem| problem[:kind] == :ignored }, problems.inspect
      assert_equal code, fixed
    end
  end

  def test_partial_suppression_prevents_edits_across_the_ignored_region
    code = "class example (\n  String $a = 'a',\n  Optional[String] $long = undef, # lint:ignore:project_parameter_alignment\n) {}\n"
    problems, fixed = lint_checks(code, [:project_parameter_alignment], fix: true)
    refute_empty problems
    assert_equal code, fixed
    code = "Notify['target'] -> File[\n  '/z',\n  '/a', # lint:ignore:project_resource_references\n]\n"
    problems, fixed = lint_checks(code, [:project_resource_references], fix: true)
    assert_equal [:warning], problems.map { |problem| problem[:kind] }
    assert_equal code, fixed
  end

  def test_literal_contents_and_correct_code_remain_unchanged
    code = "$text = @(TEXT)\n{\n\n'a','b'\nTEXT\n$other = 'a,b'\n$values = [\n  'a',\n]\n"
    problems, fixed = lint_checks(code, [:project_layout, :project_comment_spacing], fix: true)
    assert_empty problems
    assert_equal code, fixed
  end

  def test_all_checks_fix_the_same_region_in_one_pass
    assert_fix("Notify['target'] -> [\n      File[\"/z\"],File[\"/a\"]\n]\n",
               "Notify['target'] -> File['/a', '/z']\n")
  end

  def test_repeated_indentation_fixes_handle_empty_whitespace_tokens
    assert_fix("$command = join([\n      'first',\n      'second',\n    ], ' ')\n",
               "$command = join([\n  'first',\n  'second',\n], ' ')\n")
  end

  def test_documentation_and_comment_spacing_share_the_surviving_anchor
    before = "$value = 'example'\n# lint:ignore:140chars\n# @summary Example.\n# @api public\n# lint:endignore\nclass example {}\n"
    after = "$value = 'example'\n\n# @summary Example.\n#\n# @api public\nclass example {}\n"
    assert_fix(before, after, :project_documentation_layout, :project_comment_spacing)
  end

  def test_layout_does_not_move_comments_between_comma_and_value
    code = "$values = [1,/* Keep this reason. */2]\n"
    problems, fixed = lint_checks(code, [:project_layout], fix: true)
    assert_equal [:warning], problems.map { |problem| problem[:kind] }
    assert_equal code, fixed
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

  def test_heredoc_parameter_endings_remain_manual_without_changing_the_body
    code = "class example (\n  String $label = @(TEXT)\nLiteral {\n\n'a','b'\nTEXT\n) {}\n"
    problems, fixed = lint_checks(code, [:project_layout], fix: true)
    assert_equal [:warning], problems.map { |problem| problem[:kind] }
    assert_equal code, fixed
    assert_equal code, lint_checks(fixed, [:project_layout], fix: true).last
  end
end
