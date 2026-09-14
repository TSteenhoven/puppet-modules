# frozen_string_literal: true

require_relative 'reference_test_case'

# Verify reference safety behavior through the native linter.
class ReferenceSafetyTest < ReferenceTestCase
  def test_intervening_expressions_require_review_without_hiding_duplicate_types
    ['$extra', 'example::references()', "[Package['nested']]", 'Service[$name]'].each do |other|
      code = "Notify['target'] -> [Package['z'], #{other}, Package['a']]\n"
      assert_preserved(code, [:warning], review: true)
    end
  end

  def test_function_arguments_relationship_chains_and_nested_arrays_keep_their_structure
    assert_unchanged(fixture(:sample))
    %w[-> ~> <- <~].each { |operator| assert_unchanged("Package['z'] #{operator} Package['a']\n") }
    assert_unchanged(fixture(:sample2))
    assert_fix(fixture(:sample3),
               fixture(:sample4))
    assert_fix(fixture(:sample5),
               fixture(:sample6))
  end

  def test_comments_and_dynamic_titles_require_manual_merging
    fixture(:samples).each do |code|
      assert_preserved(code, [:warning], review: true)
    end
    assert_unchanged(fixture(:sample9))
  end

  def test_nonadjacent_references_preserve_full_and_partial_suppressions
    code = fixture(:code)
    ignored = "# lint:ignore:project_resource_references\n#{code}# lint:endignore\n"
    assert_preserved(ignored, [:ignored])
    ["Service['nginx'],", "Package['a'],"].each do |entry|
      partial = code.sub(entry, "#{entry} # lint:ignore:project_resource_references")
      assert_preserved(partial, [:warning])
    end
  end

  def test_trailing_comment_is_preserved
    assert_fix(fixture(:sample),
               fixture(:sample2))
  end

  def test_ordinary_values_and_observable_relationship_results_are_not_rewritten
    fixture(:samples).each do |code|
      assert_preserved(code, [:warning], review: true)
    end
  end
end
