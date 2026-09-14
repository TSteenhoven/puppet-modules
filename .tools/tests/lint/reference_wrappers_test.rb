# frozen_string_literal: true

require_relative 'reference_test_case'

# Verify reference wrappers behavior through the native linter.
class ReferenceWrappersTest < ReferenceTestCase
  def test_multiline_groups_remove_the_outer_array_and_its_trailing_comma
    assert_fix(fixture(:sample),
               fixture(:sample2))
  end

  def test_metaparameters_and_relationship_lists
    %w[require before notify subscribe].each { |attribute| assert_reference_lists(attribute) }
    assert_fix(fixture(:sample),
               fixture(:sample2), count: 2)
    %w[-> ~> <- <~].each do |operator|
      assert_fix("[File['/z'], Service['nginx'], File['/a']] #{operator} " \
                 "[Package['z'], Notify['other'], Package['a']]\n",
                 "[File['/a', '/z'], Service['nginx']] #{operator} [Package['a', 'z'], Notify['other']]\n", count: 2)
    end
  end

  def test_single_reference_arrays_are_unwrapped_in_every_metaparameter
    %w[require before notify subscribe].each do |attribute|
      fixture(:samples).each do |reference|
        assert_fix("notify { 'example': #{attribute} => [#{reference}] }\n",
                   "notify { 'example': #{attribute} => #{reference} }\n")
      end
    end
  end

  def test_single_reference_arrays_are_unwrapped_on_both_sides_of_relationships
    %w[-> ~> <- <~].each do |operator|
      assert_fix("[File['/a', '/b']] #{operator} [Service['example']]\n",
                 "File['/a', '/b'] #{operator} Service['example']\n", count: 2)
    end
    assert_fix(fixture(:sample), fixture(:sample2))
  end

  def test_single_reference_array_whitespace_and_trailing_comma
    assert_fix(fixture(:sample),
               fixture(:sample2))
    assert_fix(fixture(:sample3),
               fixture(:sample4))
    assert_fix(fixture(:sample5),
               fixture(:sample6))
  end

  def test_unwrapping_preserves_comments_suppressions_and_heredocs
    fixture(:samples).each do |code|
      assert_preserved(code, [:warning], review: true)
    end
    code = fixture(:code)
    assert_preserved(code, [:ignored])
  end

  def test_single_reference_arrays_outside_relationship_consumers_are_unchanged
    fixture(:samples).each { |code| assert_unchanged(code) }
  end

  def assert_reference_lists(attribute)
    assert_fix("notify { 'example': #{attribute} => [Service['nginx'], Service['apache2']] }\n",
               "notify { 'example': #{attribute} => Service['apache2', 'nginx'] }\n")
    assert_fix("notify { 'example': #{attribute} => [Package['z'], Service['nginx'], Package['a']] }\n",
               "notify { 'example': #{attribute} => [Package['a', 'z'], Service['nginx']] }\n")
  end
end
