# frozen_string_literal: true

require_relative 'reference_test_case'

# Verify reference literals behavior through the native linter.
class ReferenceLiteralsTest < ReferenceTestCase
  def test_correct_references_keep_their_formatting
    assert_unchanged(fixture(:sample))
    assert_unchanged(fixture(:sample2))
    assert_unchanged(fixture(:sample3))
  end

  def test_multiline_sort_preserves_whitespace_slots
    assert_fix(fixture(:sample),
               fixture(:sample2))
  end

  def test_data_types_and_lookups_are_not_resource_references
    assert_unchanged(fixture(:sample))
    assert_unchanged("$value = $lookup['z', 'a']\n")
    assert_unchanged(fixture(:sample2))
    assert_unchanged(fixture(:sample3))
  end

  def test_sort_uses_literal_values_and_preserves_quotes_escapes_and_duplicates
    assert_fix(fixture(:sample),
               fixture(:sample2))
    assert_fix(fixture(:sample3), fixture(:sample4))
    assert_fix(fixture(:sample5), fixture(:sample6))
  end

  def test_unicode_positions_and_titles
    assert_fix(fixture(:sample), fixture(:sample2))
    assert_fix(fixture(:sample3),
               fixture(:sample4))
  end

  def test_strings_and_comments_are_not_code
    assert_unchanged(fixture(:sample))
    assert_unchanged(fixture(:sample2))
  end

  def test_diagnostic_location_and_message_do_not_expose_titles
    problems, = lint(fixture(:sample))
    assert_equal([[2, 3]], problems.map { |problem| problem.values_at(:line, :column) })
    refute_includes problems.first[:message], 'synthetic'
  end
end
