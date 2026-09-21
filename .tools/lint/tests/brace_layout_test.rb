# frozen_string_literal: true

require_relative 'test_helper'

# Verify the brace layout contract with native lint diagnostics.
class BraceLayoutTest < Minitest::Test
  include LintTestSupport

  BRACE_CONTEXTS = [
    ['class example {', '}'], ['define example {', '}'], ['if $active {', '}'], ['unless $active {', '}'],
    ['if $active {} else {', '}'], ['if $active {} elsif $fallback {', '}'],
    ['case $state {', "  default: {}\n}"], ['case $state { default: {', '} }'],
    ['[1].each |$value| {', '}'], ['$values = {', "  'key' => 'value',\n}"],
    ['$value = $active ? {', "  default => undef,\n}"], ['notify {', "  'synthetic':\n}"]
  ].freeze

  def test_layout_rejects_blank_lines_after_opening_braces_in_nested_blocks
    code = fixture('brace_layout/braces_in_nested_blocks_code')
    problems = findings(code, 'project_layout')
    assert_equal([3, 6], problems.map { |problem| problem.fetch(:line) })
    assert(problems.all? { |problem| problem[:kind] == :warning && problem[:column] == 1 })
    assert(problems.all? { |problem| problem[:message] == 'Remove blank lines immediately after an opening brace' })

    assert_valid_brace_spacing(code.gsub("\n\n", "\n"))
  end

  def test_layout_checks_braces_in_declarations_collections_and_control_flow
    BRACE_CONTEXTS.each do |opening, closing|
      code = "#{opening}\n\n#{closing}\n"
      assert_equal [2], findings(code, 'project_layout').map { |problem| problem.fetch(:line) }, opening
      assert_empty findings(code.sub("\n\n", "\n"), 'project_layout'), opening
    end
  end

  def test_layout_reports_the_first_blank_line_including_whitespace_and_inline_comments
    ['', ' # Explain the body.', ' # lint:ignore:140chars', ' /* Explain the body. */'].each do |suffix|
      ["\n\n", "\n \t\n\n", "\r\n \t\r\n\r\n"].each do |spacing|
        code = "if $active {#{suffix}#{spacing}  notice('Active')\n}\n"
        assert_equal [2], findings(code, 'project_layout').map { |problem| problem.fetch(:line) }, code
      end
    end
  end

  def test_layout_preserves_content_and_spacing_elsewhere_in_blocks
    sources = ["if $active {}\n", "if $active {\n}\n"]
    sources += fixture_set('brace_layout/spacing_elsewhere_in_blocks_sources6_*')
    sources.each { |code| assert_empty findings(code, 'project_layout'), code }
  end

  def assert_valid_brace_spacing(code)
    %w[project_layout project_comment_spacing project_if_sections].each do |rule|
      assert_empty findings(code, rule)
    end
  end
end
