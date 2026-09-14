# frozen_string_literal: true

require_relative 'test_helper'

# Verify documentation suppressions behavior through the native linter.
class DocumentationSuppressionsTest < Minitest::Test
  include LintTestSupport
  include LintTestSupport::DocumentationInputs

  RULE = :project_documentation_layout
  def test_summary_cannot_use_a_literal_length_exception
    code = "# lint:ignore:140chars\n# @summary `#{'x' * 150}`\n# lint:endignore\nclass example {}\n"
    problems, = lint(code)
    assert_includes problems.first[:message], 'Shorten @summary'
  end

  def test_unnecessary_suppression_is_removed_and_long_prose_is_wrapped
    before = document("# lint:ignore:140chars\n# #{PROSE}\n# lint:endignore\n")
    _, expected = lint(document("# #{PROSE}\n"), fix: true)
    assert_fix(before, expected)
    assert_fix(document("# lint:ignore:140chars\n# Short prose.\n# lint:endignore\n"),
               document("# Short prose.\n"))
  end

  def test_unbreakable_inline_literal_requires_a_targeted_exception
    body = "# `#{'value  ' * 24}`\n"
    code = document(body)
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_includes problems.first[:message], 'maximum 140-character'
    assert_clean_passes(document("# lint:ignore:140chars\n#{body}# lint:endignore\n"))
  end

  def test_long_literal_in_example_can_have_a_targeted_exception
    assert_clean_passes(document("# @example Literal value\n# lint:ignore:140chars\n" \
                                 "#   $value = '#{'value ' * 30}'\n# lint:endignore\n"))
  end

  def test_multiple_declarations_and_nested_suppressions_preserve_their_scope
    first = document("# lint:ignore:140chars\n# #{PROSE}\n# lint:endignore\n")
    second = document("# #{PROSE}\n", 'define other {}')
    _, fixed = lint("#{first}\n#{second}", fix: true)
    assert_clean_passes(fixed)
    code = document(fixture('documentation_suppressions/suppressions_preserve_their_scope_code'))
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_includes problems.first[:message], '[review]'
  end

  def test_suppression_that_also_covers_puppet_code_requires_manual_narrowing
    code = "# lint:ignore:140chars\n#{document("# Short prose.\n")}# lint:endignore\n"
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_includes problems.first[:message], '[review]'
  end

  def test_mixed_or_commented_suppressions_are_not_deleted
    [
      "# lint:ignore:140chars Preserve this reason.\n# Short description.\n# lint:endignore\n",
      "# lint:ignore:140chars lint:ignore:puppet_url_without_modules\n# Short description.\n# lint:endignore\n",
      "# lint:ignore:140chars\n# Short description.\n# `#{'value ' * 30}`\n# lint:endignore\n"
    ].each do |body|
      code = document(body)
      problems, fixed = lint(code, fix: true)
      assert_equal code, fixed
      assert_includes problems.last[:message], '[review]'
    end
  end

  def test_mentioning_a_length_directive_in_another_suppression_reason_does_not_disable_it
    code = document(fixture('documentation_suppressions/does_not_disable_it_code'))
    assert_clean_passes(code)
  end

  def test_code_suppression_survives_documentation_fix
    body = "# lint:ignore:140chars\n# #{PROSE}\n# lint:endignore\n"
    suffix = "$value = '#{'x' * 150}' # lint:ignore:140chars\n"
    _, fixed = lint(document(body) + suffix, fix: true)
    assert fixed.end_with?(suffix)
    assert_clean_passes(fixed)
  end
end
