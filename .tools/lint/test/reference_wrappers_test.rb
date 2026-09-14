# frozen_string_literal: true

require_relative 'test_helper'

# Verify reference wrappers behavior through the native linter.
class ReferenceWrappersTest < Minitest::Test
  include LintTestSupport

  RULE = :project_resource_references
  def test_multiline_groups_remove_the_outer_array_and_its_trailing_comma
    assert_fix("Notify['target'] -> [\n  File['/z'],\n  File['/b', '/a'],\n]\n",
               "Notify['target'] -> File[\n  '/a',\n  '/b',\n  '/z',\n]\n")
  end

  def test_metaparameters_and_relationship_lists
    %w[require before notify subscribe].each { |attribute| assert_reference_lists(attribute) }
    assert_fix("[File['/z'], File['/a']] -> Service['z', 'a']\n",
               "File['/a', '/z'] -> Service['a', 'z']\n", count: 2)
    %w[-> ~> <- <~].each do |operator|
      assert_fix("[File['/z'], Service['nginx'], File['/a']] #{operator} " \
                 "[Package['z'], Notify['other'], Package['a']]\n",
                 "[File['/a', '/z'], Service['nginx']] #{operator} [Package['a', 'z'], Notify['other']]\n", count: 2)
    end
  end

  def test_single_reference_arrays_are_unwrapped_in_every_metaparameter
    %w[require before notify subscribe].each do |attribute|
      ["Package['a', 'b']", "Service['example']", "Class['example']", 'Example::Widget[$title]',
       'File["${root}/a", $other]', "File[join($parts, '/')]"].each do |reference|
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
    assert_fix("Notify['target'] -> ([Package['a', 'b']])\n", "Notify['target'] -> (Package['a', 'b'])\n")
  end

  def test_single_reference_array_whitespace_and_trailing_comma
    assert_fix("notify { 'example':\n  require => [ Package['a', 'b'], ],\n}\n",
               "notify { 'example':\n  require => Package['a', 'b'],\n}\n")
    assert_fix(fixture('reference_wrappers/whitespace_and_trailing_comma_sample3'),
               fixture('reference_wrappers/whitespace_and_trailing_comma_sample4'))
    assert_fix("Notify['target'] -> [\n  File['line one\n  line two'],\n]\n",
               "Notify['target'] -> File['line one\n  line two']\n")
  end

  def test_unwrapping_preserves_comments_suppressions_and_heredocs
    ["Notify['target'] -> [ # Keep this explanation.\n  Package['a', 'b'],\n]\n",
     "Notify['target'] -> [\n  Package['a', 'b'], # Keep this explanation.\n]\n",
     "Notify['target'] -> [\n  Package['a', 'b'],\n] # lint:ignore:project_resource_references\n",
     "Notify['target'] -> [File[@(TEXT)]]\n/tmp/example\nTEXT\n"].each do |code|
      assert_preserved(code, [:warning], review: true)
    end
    code = "# lint:ignore:project_resource_references\nNotify['target'] -> [Package['a', 'b']]\n# lint:endignore\n"
    assert_preserved(code, [:ignored])
  end

  def test_single_reference_arrays_outside_relationship_consumers_are_unchanged
    ["$refs = [Package['a', 'b']]\n", "example::call([Package['a', 'b']])\n", "$ref = [Package['a', 'b']][0]\n",
     "notify { 'example': message => [Package['a', 'b']] }\n",
     "$refs = Notify['target'] -> [Package['a', 'b']]\n",
     "Notify['target'] -> [[Package['a', 'b']]]\n",
     "Notify['target'] -> [Package['a', 'b'], Service['example']]\n"].each do |code|
      assert_clean_passes(code)
    end
  end

  def assert_reference_lists(attribute)
    assert_fix("notify { 'example': #{attribute} => [Service['nginx'], Service['apache2']] }\n",
               "notify { 'example': #{attribute} => Service['apache2', 'nginx'] }\n")
    assert_fix("notify { 'example': #{attribute} => [Package['z'], Service['nginx'], Package['a']] }\n",
               "notify { 'example': #{attribute} => [Package['a', 'z'], Service['nginx']] }\n")
  end
end
