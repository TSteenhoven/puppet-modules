# frozen_string_literal: true

require_relative 'documentation_test_case'

# Verify documentation structure behavior through the native linter.
class DocumentationStructureTest < DocumentationTestCase
  def test_summary_requires_manual_shortening_without_deleting_text
    code = "# @summary #{PROSE}\n#\n# @api public\nclass example {}\n"
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_includes problems.first[:message], '[review]'
    code = fixture(:code)
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_includes problems.first[:message], 'Keep @summary on one line'
  end

  def test_summary_overview_and_tag_sections_get_comment_separators
    before = fixture(:before)
    after = before.sub("example.\n# Description", "example.\n#\n# Description")
                  .sub("Description.\n# @example", "Description.\n#\n# @example")
                  .sub("include example\n# @api", "include example\n#\n# @api")
    assert_fix(before, after)
  end

  def test_short_inline_parameters_are_allowed_and_parameter_order_is_preserved
    before = document(fixture(:before))
    after = before.sub("description.\n# @param second", "description.\n#\n# @param second")
    assert_fix(before, after)
  end

  def test_continuation_indentation_is_corrected_for_parameters_and_other_tags
    %w[param note return].each do |tag|
      ['', ' ', '   ', '    '].each do |indent|
        body = "# @#{tag} label\n# #{indent}Description with a default.\n"
        assert_fix(document(body), document("# @#{tag} label\n#   Description with a default.\n"))
      end
      assert_clean(document("# @#{tag} label\n#   Description with a default.\n"))
    end
  end

  def test_source_blank_line_is_replaced_with_a_comment
    before = document("# Description.\n\n# More detail.\n")
    assert_fix(before, before.sub("Description.\n\n", "Description.\n#\n"))
  end
end
