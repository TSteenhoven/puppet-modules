# frozen_string_literal: true

require_relative 'test_helper'

# Verify reference merging behavior through the native linter.
class ReferenceMergingTest < Minitest::Test
  include LintTestSupport

  RULE = :project_resource_references
  def test_two_package_references
    assert_fix("Notify['target'] -> [Package['console-setup'], Package['keyboard-configuration']]\n",
               "Notify['target'] -> Package['console-setup', 'keyboard-configuration']\n")
  end

  def test_multiple_references_and_titles_are_sorted_together
    assert_fix("Notify['target'] -> [Package['zulu', 'charlie'], Package['bravo'], Package['alpha', 'delta']]\n",
               "Notify['target'] -> Package['alpha', 'bravo', 'charlie', 'delta', 'zulu']\n")
  end

  def test_unsorted_combined_reference
    assert_fix("Notify['target'] -> Package['keyboard-configuration', 'console-setup']\n",
               "Notify['target'] -> Package['console-setup', 'keyboard-configuration']\n")
  end

  def test_service_file_class_and_arbitrary_defined_types
    { 'Service' => %w[apache2 nginx], 'File' => ['/etc/a.conf', '/etc/z.conf'], 'Class' => %w[alpha zulu],
      'Example::Widget' => %w[alpha zulu], 'Custom_type' => %w[alpha zulu] }.each do |type, (first, last)|
      assert_fix("Notify['target'] -> [#{type}['#{last}'], #{type}['#{first}']]\n",
                 "Notify['target'] -> #{type}['#{first}', '#{last}']\n")
      assert_fix("Notify['target'] -> [#{type}['#{last}'], Notify['other'], #{type}['#{first}']]\n",
                 "Notify['target'] -> [#{type}['#{first}', '#{last}'], Notify['other']]\n")
    end
  end

  def test_nonadjacent_references_merge_at_the_first_occurrence
    assert_fix("Notify['target'] -> [Package['zulu'], Service['nginx'], Package['alpha']]\n",
               "Notify['target'] -> [Package['alpha', 'zulu'], Service['nginx']]\n")
    assert_fix("Notify['target'] -> [Service['nginx'], Package['zulu'], File['/a'], " \
               "Package['alpha'], Notify['other']]\n",
               "Notify['target'] -> [Service['nginx'], Package['alpha', 'zulu'], File['/a'], Notify['other']]\n")
    assert_clean_passes("Notify['target'] -> [Service['nginx'], Package['alpha'], File['/a']]\n")
  end

  def test_multiple_independent_groups
    assert_fix("Notify['target'] -> [Package['z'], Package['a'], File['/z'], File['/a'], Package['b']]\n",
               "Notify['target'] -> [Package['a', 'b', 'z'], File['/a', '/z']]\n", count: 2)
    assert_fix("Notify['target'] -> [Package['z'], File['/z'], Service['z'], Package['b', " \
               "'a'], File['/a'], Service['a']]\n",
               "Notify['target'] -> [Package['a', 'b', 'z'], File['/a', '/z'], Service['a', 'z']]\n", count: 3)
  end

  def test_nonadjacent_multiline_references_keep_other_entries_and_trailing_commas
    before = fixture('reference_merging/entries_and_trailing_commas_before')
    after = "Notify['target'] -> [\n  Package['a', 'z'],\n  Service['a', 'z'],\n]\n"
    assert_fix(before, after, count: 2)
    assert_fix(before.sub("Service['a'],\n", "Service['a']\n"),
               after.sub("Service['a', 'z'],\n", "Service['a', 'z']\n"), count: 2)
    assert_fix(fixture('reference_merging/entries_and_trailing_commas_sample'),
               fixture('reference_merging/entries_and_trailing_commas_sample4'))
  end

  def test_resource_type_case_does_not_split_a_group
    assert_fix("Notify['target'] -> [Example::Widget['z'], Example::WIDGET['a']]\n",
               "Notify['target'] -> Example::Widget['a', 'z']\n")
    assert_fix("Notify['target'] -> [Example::Widget['z'], Service['other'], Example::WIDGET['a']]\n",
               "Notify['target'] -> [Example::Widget['a', 'z'], Service['other']]\n")
  end

  def test_identical_references_in_different_positions_are_each_checked
    assert_fix("Notify['target'] -> [File['z', 'a']]\nNotify['other'] -> File['z', 'a']\n",
               "Notify['target'] -> File['a', 'z']\nNotify['other'] -> File['a', 'z']\n", count: 2)
  end
end
