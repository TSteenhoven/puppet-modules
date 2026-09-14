# frozen_string_literal: true

require_relative 'test_helper'

# Verify reference safety behavior through the native linter.
class ReferenceSafetyTest < Minitest::Test
  include LintTestSupport

  RULE = :project_resource_references
  def test_intervening_expressions_require_review_without_hiding_duplicate_types
    ['$extra', 'example::references()', "[Package['nested']]", 'Service[$name]'].each do |other|
      code = "Notify['target'] -> [Package['z'], #{other}, Package['a']]\n"
      assert_preserved(code, [:warning], review: true)
    end
  end

  def test_function_arguments_relationship_chains_and_nested_arrays_keep_their_structure
    assert_clean_passes("example::call(Package['z'], Package['a'])\n")
    %w[-> ~> <- <~].each { |operator| assert_clean_passes("Package['z'] #{operator} Package['a']\n") }
    assert_clean_passes("Notify['target'] -> [[Package['z']], [Package['a']]]\n")
    assert_fix("Notify['target'] -> [[Package['z'], Package['a']], Package['b']]\n",
               "Notify['target'] -> [[Package['a', 'z']], Package['b']]\n")
    assert_fix("Notify['target'] -> [[Package['z'], Service['nginx'], Package['a']], Package['b']]\n",
               "Notify['target'] -> [[Package['a', 'z'], Service['nginx']], Package['b']]\n")
  end

  def test_comments_and_dynamic_titles_require_manual_merging
    ["Notify['target'] -> [Package['z'], # Keep this explanation.\n  Package['a']]\n",
     "Notify['target'] -> [Package['z'], Service['nginx'], # Keep this explanation.\n  Package['a']]\n",
     "Notify['target'] -> [Package['z'], Service['nginx'], Package['a'], # Explain the last package.\n]\n",
     "Notify['target'] -> [Package['z'], Service['nginx'], Package['a'] /* Explain the last package. */]\n",
     "Notify['target'] -> [Package[$name], Service['nginx'], Package['a']]\n",
     "Notify['target'] -> File['/z', /* Keep this explanation. */ '/a']\n",
     "Notify['target'] -> [File[$path], File[\"${root}/a\"]]\n",
     "Notify['target'] -> [File[join($parts, '/')], File['/a']]\n"].each do |code|
      assert_preserved(code, [:warning], review: true)
    end
  end

  def test_one_reference_keeps_dynamic_titles
    assert_clean_passes("Notify['target'] -> File[$path, \"${root}/a\"]\n")
  end

  def test_nonadjacent_references_preserve_full_and_partial_suppressions
    code = "Notify['target'] -> [\n  Package['z'],\n  Service['nginx'],\n  Package['a'],\n]\n"
    ignored = "# lint:ignore:project_resource_references\n#{code}# lint:endignore\n"
    assert_preserved(ignored, [:ignored])
    ["Service['nginx'],", "Package['a'],"].each do |entry|
      partial = code.sub(entry, "#{entry} # lint:ignore:project_resource_references")
      assert_preserved(partial, [:warning])
    end
  end

  def test_trailing_comment_is_preserved
    assert_fix("Notify['target'] -> [Package['z'], Package['a']] # Keep the outer explanation.\n",
               "Notify['target'] -> Package['a', 'z'] # Keep the outer explanation.\n")
  end

  OBSERVABLE_VALUES = [
    "$refs = [Package['z'], Package['a']]\n", "$refs = File['z', 'a']\n", "$first = File['z', 'a'][0]\n",
    "example::call(File['z', 'a'])\n",
    "$refs = Notify['target'] -> [File['z'], File['a']]\n",
    "$refs = [1].map |$item| { Notify['target'] -> File['z', 'a'] }\n",
    "$refs = { 'require' => [File['z'], File['a']] }\n",
    "$refs = [Package['z'], Service['nginx'], Package['a']]\n",
    "example::call([Package['z'], Service['nginx'], Package['a']])\n",
    "$first = [Package['z'], Service['nginx'], Package['a']][0]\n",
    "notify { 'example': message => [Package['z'], Service['nginx'], Package['a']] }\n",
    "$refs = Notify['target'] -> [Package['z'], Service['nginx'], Package['a']]\n"
  ].freeze

  def test_ordinary_values_and_observable_relationship_results_are_not_rewritten
    OBSERVABLE_VALUES.each { |code| assert_preserved(code, [:warning], review: true) }
  end
end
