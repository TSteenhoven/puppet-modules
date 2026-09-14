# frozen_string_literal: true

require_relative 'test_helper'

# Verify the resource sections contract with native lint diagnostics.
class ResourceSectionsTest < Minitest::Test
  include LintTestSupport

  RESOURCE_FORMS = ["basic_settings::monitoring_custom { 'example': }", "Notify { message => 'default' }",
                    "Notify['example'] { message => 'override' }",
                    "@notify { 'example': }",
                    "@@notify { 'example': }",
                    "class { 'example': }"].freeze

  def test_resource_sections_keep_line_numbers_after_blank_lines
    code = "notify { 'first': }\n\nnotify { 'second': }\n\n"
    assert_equal([3], findings(code, 'project_resource_sections').map { |finding| finding[:line] })
  end

  def test_resource_sections_after_conditions_need_their_own_explanation
    code = fixture('resource_sections/need_their_own_explanation_code')
    assert_equal([[6, 1]], findings(code, 'project_resource_sections').map do |problem|
      problem.values_at(:line, :column)
    end)
    refute_empty findings(code.sub("\nnotify", "\n\nnotify"), 'project_resource_sections')
    corrected = code.sub("\nnotify", "\n\n# Report the selected state.\nnotify")
    assert_valid_section(corrected)
    assert_unseparated_explanation(code.sub("\nnotify", "\n# Report the selected state.\nnotify"))
  end

  def test_resource_sections_cover_defined_types_defaults_overrides_and_virtual_resources
    RESOURCE_FORMS.each do |declaration|
      code = "if $active { $value = 1 }\n#{declaration}\n"
      assert_equal [:warning], finding_kinds(code, 'project_resource_sections'), declaration
      assert_empty findings(code.sub("\n",
                                     "\n\n# Register the selected instance.\n"),
                            'project_resource_sections'),
                   declaration
    end
  end

  def test_resource_sections_recognize_closed_expressions_and_same_line_resources
    preceding = ["notify { 'first': }", "$options = { 'message' => 'example' }",
                 "$message = $active ? { true => 'yes', default => 'no' }",
                 "$items = ['one'].map |$item| { $item }",
                 "case $active { default: { $message = 'example' } }"]
    preceding.each do |statement|
      ["\n", ' ', ";\n"].each do |separator|
        code = "#{statement}#{separator}notify { 'second': }\n"
        assert_equal [:warning], finding_kinds(code, 'project_resource_sections'), code
      end
    end
  end

  def test_resource_sections_do_not_split_relationship_chains_or_opening_blocks
    %w[-> ~> <- <~].each do |relationship|
      assert_empty findings("notify { 'first': } #{relationship}\nnotify { 'second': }\n", 'project_resource_sections')
    end
    assert_empty findings("if $active {\n  notify { 'example': }\n}\n", 'project_resource_sections')
    assert_empty findings("$message = '} # literal'\nnotify { 'example': }\n", 'project_resource_sections')
    assert_empty findings("$options = [1, 2]\nnotify { 'example': }\n", 'project_resource_sections')
  end

  def test_section_positions_handle_crlf_and_multibyte_text
    code = "notify { 'caf\u00E9': } notify { 'next': }\r\n# Explain the next value.\r\n$value = 1\r\n"
    assert_equal([:warning], finding_kinds(code, 'project_resource_sections'))
    assert_equal([2], finding_lines(code, 'project_comment_spacing'))
  end

  def test_resource_sections_reject_empty_trailing_and_control_only_comments
    ["#\n", "# lint:ignore:140chars\n# lint:endignore\n", "# Explain the previous block.\n\n"].each do |comment|
      refute_empty findings("if $active { $value = 1 }\n\n#{comment}notify { 'example': }\n",
                            'project_resource_sections')
    end
    refute_empty findings("if $active { $value = 1 } # Explain this condition.\nnotify { 'example': }\n",
                          'project_resource_sections')
    code = fixture('resource_sections/and_control_only_comments_code')
    assert_empty findings(code, 'project_resource_sections')
    assert_empty findings(code, 'project_comment_spacing')
  end

  def assert_unseparated_explanation(code)
    assert_empty findings(code, 'project_resource_sections')
    refute_empty findings(code, 'project_comment_spacing')
  end

  def assert_valid_section(code)
    assert_empty findings(code, 'project_resource_sections')
    assert_empty findings(code, 'project_comment_spacing')
  end
end
