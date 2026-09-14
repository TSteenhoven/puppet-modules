# frozen_string_literal: true

require_relative 'reference_test_case'

# Verify reference merging behavior through the native linter.
class ReferenceMergingTest < ReferenceTestCase
  def test_two_package_references
    assert_fix(fixture(:sample),
               fixture(:sample2))
  end

  def test_multiple_references_and_titles_are_sorted_together
    assert_fix(fixture(:sample),
               fixture(:sample2))
  end

  def test_unsorted_combined_reference
    assert_fix(fixture(:sample),
               fixture(:sample2))
  end

  def test_service_file_class_and_arbitrary_defined_types
    fixture(:titles).each do |type, (first, last)|
      assert_fix("Notify['target'] -> [#{type}['#{last}'], #{type}['#{first}']]\n",
                 "Notify['target'] -> #{type}['#{first}', '#{last}']\n")
      assert_fix("Notify['target'] -> [#{type}['#{last}'], Notify['other'], #{type}['#{first}']]\n",
                 "Notify['target'] -> [#{type}['#{first}', '#{last}'], Notify['other']]\n")
    end
  end

  def test_nonadjacent_references_merge_at_the_first_occurrence
    assert_fix(fixture(:sample),
               fixture(:sample2))
    assert_fix(fixture(:sample3),
               fixture(:sample4))
    assert_unchanged(fixture(:sample5))
  end

  def test_multiple_independent_groups
    assert_fix(fixture(:sample),
               fixture(:sample2), count: 2)
    assert_fix(fixture(:sample3),
               fixture(:sample4), count: 3)
  end

  def test_nonadjacent_multiline_references_keep_other_entries_and_trailing_commas
    before = fixture(:before)
    after = fixture(:after)
    assert_fix(before, after, count: 2)
    assert_fix(before.sub("Service['a'],\n", "Service['a']\n"),
               after.sub("Service['a', 'z'],\n", "Service['a', 'z']\n"), count: 2)
    assert_fix(fixture(:sample),
               fixture(:sample4))
  end

  def test_resource_type_case_does_not_split_a_group
    assert_fix(fixture(:sample),
               fixture(:sample2))
    assert_fix(fixture(:sample3),
               fixture(:sample4))
  end

  def test_identical_references_in_different_positions_are_each_checked
    assert_fix(fixture(:sample),
               fixture(:sample2), count: 2)
  end
end
