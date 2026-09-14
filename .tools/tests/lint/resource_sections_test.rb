# frozen_string_literal: true

require_relative 'check_test_case'

# Verify the resource sections contract with native lint diagnostics.
class ResourceSectionsTest < CheckTestCase
  def test_resource_sections_keep_line_numbers_after_blank_lines
    code = fixture(:code)
    assert_equal([3], findings(code, 'project_resource_sections').map { |finding| finding[:line] })
  end

  def test_resource_sections_after_conditions_need_their_own_explanation
    code = fixture(:code)
    assert_equal([[6, 1]], findings(code, 'project_resource_sections').map do |problem|
      problem.values_at(:line, :column)
    end)
    refute_empty findings(code.sub("\nnotify", "\n\nnotify"), 'project_resource_sections')
    corrected = code.sub("\nnotify", fixture(:corrected))
    assert_valid_section(corrected)
    assert_unseparated_explanation(code.sub("\nnotify", fixture(:unseparated)))
  end

  def test_resource_sections_cover_defined_types_defaults_overrides_and_virtual_resources
    declarations = fixture(:declarations)
    declarations.each do |declaration|
      code = "if $active { $value = 1 }\n#{declaration}\n"
      assert_equal [:warning], finding_kinds(code, 'project_resource_sections'), declaration
      assert_empty findings(code.sub("\n", fixture(:sample)), 'project_resource_sections'),
                   declaration
    end
  end

  def test_resource_sections_recognize_closed_expressions_and_same_line_resources
    preceding = fixture(:preceding)
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
    assert_empty findings(fixture(:sample), 'project_resource_sections')
    assert_empty findings(fixture(:sample2), 'project_resource_sections')
    assert_empty findings(fixture(:sample3), 'project_resource_sections')
  end

  def test_section_positions_handle_crlf_and_multibyte_text
    code = fixture(:code)
    assert_equal([:warning], finding_kinds(code, 'project_resource_sections'))
    assert_equal([2], finding_lines(code, 'project_comment_spacing'))
  end

  def test_resource_sections_reject_empty_trailing_and_control_only_comments
    ["#\n", fixture(:sample), "# Explain the previous block.\n\n"].each do |comment|
      refute_empty findings("if $active { $value = 1 }\n\n#{comment}notify { 'example': }\n",
                            'project_resource_sections')
    end
    refute_empty findings(fixture(:sample2), 'project_resource_sections')
    code = fixture(:code)
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
