# frozen_string_literal: true

require_relative 'documentation_test_case'

# Verify documentation scope behavior through the native linter.
class DocumentationScopeTest < DocumentationTestCase
  def test_nested_list_continuations_keep_their_indentation
    code = document("# @param value\n#   - First item.\n#     Continuation of the item.\n#\n#     #{PROSE}\n")
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
    assert_includes problems.first[:message], '[review]'
  end

  def test_fences_protect_tag_like_code_and_mismatched_closing_fences
    body = "# ````text\n# @param literal\n# ```\n# #{PROSE}\n# ````\n"
    code = document(body)
    problems, fixed = lint(code, fix: true)
    assert_equal code, fixed
    assert_equal([:warning], problems.map { |problem| problem[:kind] })
  end

  def test_wrapping_cannot_create_tags_or_markdown_structure
    ['@param value', '- an item', '1. an item', '> a quote', '# a heading'].each do |ending|
      code = document("# #{'x' * 117} #{ending}\n")
      problems, fixed = lint(code, fix: true)
      assert_equal code, fixed
      assert_includes problems.first[:message], '[review]'
    end
  end

  def test_short_typed_parameter_descriptions_satisfy_interface_validation
    code = fixture(:code)
    assert_empty lint(code, rule: :project_documentation).first
  end

  def test_comments_in_strings_and_ordinary_comments_are_outside_scope
    assert_clean("$value = @(TEXT)\n# #{PROSE}\nTEXT\n")
    assert_clean("$value = '\n# #{PROSE}\n'\n")
    assert_clean("# #{PROSE}\n$value = 'example'\n")
    assert_clean("/* # #{PROSE} */\n$value = 'example'\n")
  end

  def test_classes_defined_types_functions_and_type_aliases_use_the_same_check
    ['class example {}', 'define example () {}', 'function example () {}',
     'type Example = String'].each do |declaration|
      problems, fixed = lint(document("# #{PROSE}\n", declaration), fix: true)
      assert(problems.all? { |problem| problem[:kind] == :fixed })
      assert fixed.end_with?("#{declaration}\n")
      assert_clean(fixed)
    end
  end

  def test_diagnostics_do_not_disclose_source_values
    problems, = lint(document("# #{PROSE}\n"))
    refute_includes problems.to_json, 'console'
  end

  def test_interface_validation_still_checks_tag_order_with_blank_source_lines
    code = fixture(:code)
    assert_empty lint(code, rule: :project_documentation).first
    refute_empty lint(code.sub('@param label', '@param other'), rule: :project_documentation).first
  end
end
