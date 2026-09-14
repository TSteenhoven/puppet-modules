# frozen_string_literal: true

require_relative 'test_helper'

# Verify documentation markup behavior through the native linter.
class DocumentationMarkupTest < Minitest::Test
  include LintTestSupport
  include LintTestSupport::DocumentationInputs

  RULE = :project_documentation_layout
  def test_wrapped_sentences_and_real_paragraphs_are_already_valid
    assert_clean_passes(document(fixture('documentation_markup/paragraphs_are_already_valid_sample')))
  end

  def test_inline_code_paths_and_embedded_whitespace_are_preserved
    body = "# #{'word ' * 18}`Package['example']` `/etc/default/keyboard` " \
           "``a `tick` and  spaces`` `true` `false` `undef`.\n"
    problems, fixed = lint(document(body), fix: true)
    assert(problems.all? { |problem| problem[:kind] == :fixed })
    ["`Package['example']`", '`/etc/default/keyboard`', '``a `tick` and  spaces``', '`true`', '`false`',
     '`undef`'].each do |span|
      assert_includes fixed, span
    end
    assert(fixed.lines.all? { |line| line.chomp.length <= 120 })
    assert_clean_passes(fixed)
  end

  def test_multiple_paragraphs_are_not_joined_or_reordered
    code = document("# #{PROSE}\n#\n# Another paragraph.\n#\n# #{PROSE}\n")
    _, fixed = lint(code, fix: true)
    assert_equal(code.split("\n#\n").map { |p| p.gsub(/\n# */, ' ').split.join(' ') },
                 fixed.split("\n#\n").map { |p| p.gsub(/\n# */, ' ').split.join(' ') })
    assert_clean_passes(fixed)
  end

  def test_whitespace_only_comment_is_normalized_without_adding_a_paragraph
    code = "# @summary Example.\n#   \n# @api public\nclass example {}\n"
    assert_fix(code, code.sub("#   \n", "#\n"))
  end

  def test_unsafe_markdown_and_delimiters_require_review
    ["- #{PROSE}", "| #{PROSE} |", "[#{PROSE}](https://example.org)", "#{PROSE} `unclosed",
     "#{PROSE}  ", "#{PROSE}\\", "#{PROSE} \\`escaped\\`", "#{PROSE}\tvalue"].each do |text|
      code = document("# #{text}\n")
      problems, fixed = lint(code, fix: true)
      assert_equal code, fixed
      assert_includes problems.first[:message], '[review]'
    end
  end

  def test_fenced_and_indented_code_is_not_wrapped
    ["# ```text\n# #{PROSE}\n# ```\n", "#     #{PROSE}\n",
     "# @param value\n#       #{PROSE}\n"].each do |body|
      code = document(body)
      problems, fixed = lint(code, fix: true)
      assert_equal code, fixed
      refute_empty problems
      assert(problems.all? { |problem| problem[:kind] == :warning })
    end
  end
end
