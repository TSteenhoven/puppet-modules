# frozen_string_literal: true

require_relative 'test_helper'

# Verify the array layout contract with native lint diagnostics.
class ArrayLayoutTest < Minitest::Test
  include LintTestSupport

  def test_layout_handles_strings_comments_and_nested_types
    assert_empty findings("class example (\n  Enum['a', 'b'] $label = 'comma,inside',\n) {}", 'project_layout')
    refute_empty findings("class example (\n  Enum['a','b'] $label = 'comma,inside'\n) {}", 'project_layout')
  end

  def test_layout_requires_two_extra_spaces_for_array_elements_in_function_calls
    valid = fixture('array_layout/elements_in_function_calls_valid')
    [0, 2, 8, 12].each do |indent|
      code = valid.lines.map { |line| (' ' * indent) + line }.join
      assert_empty findings(code, 'project_layout')
      [0, 1, 4, 6].each { |extra| assert_element_indentation(code, indent, extra) }
    end
  end

  def test_layout_aligns_the_closing_array_bracket_with_the_opening_line
    code = "$values = join([\n  'first',\n    ], ' ')\n"
    problems = findings(code, 'project_layout')
    assert_equal([[3, 5]], problems.map { |problem| problem.values_at(:line, :column) })
    assert_includes problems.first.fetch(:message), 'closing array bracket'
    assert_empty findings(code.sub('    ]', ']'), 'project_layout')
    assert_equal([2], finding_lines("$values = [\n  ]\n", 'project_layout'))
  end

  def test_layout_checks_arrays_in_defaults_resources_hashes_and_nested_calls
    code = fixture('array_layout/hashes_and_nested_calls_code')
    assert_empty findings(code, 'project_layout')
    %w[default nested value message].each do |value|
      incorrect = code.sub(/^( +)(?='#{value}',)/, '\1  ')
      assert_equal 1, findings(incorrect, 'project_layout').length, value
    end
  end

  def test_layout_preserves_the_resource_title_level_for_arrays
    ["file { [\n", "file {\n  [\n"].each do |opening|
      code = "#{opening}    '/synthetic/first',\n    '/synthetic/second',\n  ]:\n    ensure => absent,\n}\n"
      assert_empty findings(code, 'project_layout')
      assert_equal 2, findings(code.gsub("    '/", "      '/"), 'project_layout').length
      assert_equal 1, findings(code.sub('  ]:', ']:'), 'project_layout').length
    end
  end

  def test_layout_checks_array_element_starts_without_reindenting_their_contents
    code = fixture('array_layout/without_reindenting_their_contents_code')
    assert_empty findings(code, 'project_layout')
    ['  -1,', '  (2 + 3),', '  {', '  call(', '  @(TEXT),', "  'last',"].each do |start|
      assert_equal 1, findings(code.sub(start, "  #{start}"), 'project_layout').length, start
    end
  end

  def test_layout_preserves_inline_arrays_types_accesses_and_brackets_in_text
    codes = ["$values = ['first', 'second']\n", "$values = ['first',\n  'second']\n",
             "$values = [\n  'first', 'second']\n"]
    codes << "$values = [ # Explain this list.\r\n  'first',\r\n]\r\n"
    codes += fixture_set('array_layout/and_brackets_in_text_codes6_*')
    codes.each { |code| assert_empty findings(code, 'project_layout'), code }
  end

  def assert_element_indentation(code, indent, extra)
    incorrect = code.gsub(/^ {#{indent + 2}}(?=')/, ' ' * (indent + extra))
    problems = findings(incorrect, 'project_layout')
    expected = [2, 3, 4].map { |line| [line, indent + extra + 1] }
    assert_equal(expected, problems.map { |problem| problem.values_at(:line, :column) })
    assert_array_element_warnings(problems)
  end

  def assert_array_element_warnings(problems)
    assert(problems.all? { |problem| problem[:kind] == :warning && problem[:message].include?('array element') })
  end
end
