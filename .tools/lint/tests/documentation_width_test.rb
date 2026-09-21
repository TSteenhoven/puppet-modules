# frozen_string_literal: true

require_relative 'test_helper'

# Verify documentation width behavior through the native linter.
class DocumentationWidthTest < Minitest::Test
  include LintTestSupport
  include LintTestSupport::DocumentationInputs

  RULE = :project_documentation_layout
  def test_long_prose_wraps_at_words_and_reports_maximum
    code = document("# #{PROSE}\n")
    problems, = lint(code)
    assert_equal([[3, 1]], problems.map { |problem| problem.values_at(:line, :column) })
    assert_includes problems.first[:message], 'maximum 140-character'
    expected = document('# This class manages console packages and keyboard configuration, ' \
                        "preserves explicit settings, and uses the host\n# defaults when no override " \
                        "is supplied.\n")
    assert_fix(code, expected)
  end

  def test_preferred_width_is_distinguished_from_hard_maximum
    code = document("# #{'word ' * 24}end.\n")
    problems, = lint(code)
    assert_includes problems.first[:message], 'preferred 120-character'
    refute_includes problems.first[:message], 'maximum'
    assert_clean_passes(document("# #{'word ' * 22}end.\n"))
  end

  def test_exact_line_width_boundaries_include_the_comment_prefix
    [120, 121, 140, 141].each { |width| assert_width_boundary(width) }
    code = document("##{'word ' * 27}last\n")
    problems, = lint(code)
    assert_includes problems.first[:message], 'preferred 120-character'
    refute_includes problems.first[:message], 'maximum'
  end

  def test_long_inline_parameter_moves_its_description_below_the_tag
    body = "# @param label #{PROSE}\n"
    expected = fixture('documentation_width/description_below_the_tag_expected')
    assert_fix(document(body), document(expected))
    assert_fix(document(body.sub('@param label', '@param [String] label')),
               document(expected.sub('@param label', '@param [String] label')))
  end

  def test_unparseable_long_parameter_after_wrapped_prose_keeps_its_warning
    body = "# #{PROSE}\n#\n# @param #{'x' * 145}\n"
    problems, fixed = lint(document(body), fix: true)
    assert_equal(%i[fixed warning], problems.map { |problem| problem[:kind] })
    assert_includes fixed, "# @param #{'x' * 145}\n"
    assert_includes problems.last[:message], '[review]'
  end

  def test_long_identifier_between_preferred_and_maximum_width_is_not_split
    assert_clean_passes(document("# /#{'x' * 125}\n"))
  end

  def test_url_does_not_hide_long_normal_prose
    problems, fixed = lint(document("# #{PROSE} https://example.org/path\n"), fix: true)
    assert(problems.all? { |problem| problem[:kind] == :fixed })
    assert_includes fixed, 'https://example.org/path'
    assert_clean_passes(fixed)
  end

  def test_nested_documentation_and_unicode_are_fixed_at_their_actual_width
    body = "# #{('één woord ' * 18).strip}\n"
    code = nested_document(body)
    problems, fixed = lint(code, fix: true)
    assert(problems.all? { |problem| problem[:kind] == :fixed })
    assert_equal([[4, 3]], problems.map { |problem| problem.values_at(:line, :column) })
    assert_preferred_width(fixed)
    assert_clean_passes(fixed)
  end

  def nested_document(body)
    indented = document(body, 'class outer::inner {}').lines.map { |line| "  #{line}" }.join
    "class outer {\n#{indented}}\n"
  end

  def assert_width_boundary(width)
    line = "# #{'word ' * ((width - 3) / 5)}"
    line += 'x' * (width - line.length)
    problems, = lint(document("#{line}\n"))
    if width == 120
      assert_empty problems
    else
      assert_includes problems.first[:message], width > 140 ? 'maximum 140-character' : 'preferred 120-character'
    end
  end

  def assert_preferred_width(code)
    assert(code.lines.all? { |line| line.chomp.length <= 120 })
  end
end
