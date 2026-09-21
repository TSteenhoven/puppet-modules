# frozen_string_literal: true

require_relative 'test_helper'

# Verify reference literals behavior through the native linter.
class ReferenceLiteralsTest < Minitest::Test
  include LintTestSupport

  RULE = :project_resource_references
  def test_correct_references_keep_their_formatting
    assert_clean_passes("Notify['target'] -> [Package['alpha', 'bravo', 'charlie'], Service['example']]\n")
    assert_clean_passes("Notify['target'] -> File[\n  '/etc/a.conf',\n  '/etc/z.conf',\n]\n")
    assert_clean_passes("Notify['target'] -> Package['example']\n")
  end

  def test_multiline_sort_preserves_whitespace_slots
    assert_fix("Notify['target'] -> File[\n  '/z',\n  '/a',\n  '/b',\n]\n",
               "Notify['target'] -> File[\n  '/a',\n  '/b',\n  '/z',\n]\n")
  end

  def test_data_types_and_lookups_are_not_resource_references
    assert_clean_passes("$types = [Enum['z', 'a'], Enum['b', 'a'], Pattern[/z/, /a/]]\n")
    assert_clean_passes("$value = $lookup['z', 'a']\n")
    assert_clean_passes("$types = [Timestamp['z', 'a'], Timespan['z', 'a'], Resource['file', '/tmp/a']]\n")
    assert_clean_passes("type Example::Choice = Enum['z', 'a']\n$value = Example::Choice['z', 'a']\n")
  end

  def test_sort_uses_literal_values_and_preserves_quotes_escapes_and_duplicates
    assert_fix("Notify['target'] -> File['z', \"a\\tb\", 'a b', 'a b']\n",
               "Notify['target'] -> File[\"a\\tb\", 'a b', 'a b', 'z']\n")
    assert_fix("Notify['target'] -> [Package[zulu], Package[alpha]]\n", "Notify['target'] -> Package[alpha, zulu]\n")
    assert_fix("Notify['target'] -> File['z', 'B', 'a']\n", "Notify['target'] -> File['B', 'a', 'z']\n")
  end

  def test_unicode_positions_and_titles
    assert_fix("Notify['target'] -> ['é', File['é', 'b', 'a']]\n", "Notify['target'] -> ['é', File['a', 'b', 'é']]\n")
    assert_fix("Notify['target'] -> [File['é', 'B'], Service['nginx'], File['a', 'a']]\n",
               "Notify['target'] -> [File['B', 'a', 'a', 'é'], Service['nginx']]\n")
  end

  def test_strings_and_comments_are_not_code
    assert_clean_passes("$text = \"Package['z'], Package['a']\"\n# File['/z', '/a']\n")
    assert_clean_passes("$text = @(TEXT)\nFile['z', 'a']\nTEXT\n")
  end

  def test_diagnostic_location_and_message_do_not_expose_titles
    problems, = lint("Notify['target'] -> [\n  Package['synthetic-z'],\n  Package['synthetic-a'],\n]\n")
    assert_equal([[2, 3]], problems.map { |problem| problem.values_at(:line, :column) })
    refute_includes problems.first[:message], 'synthetic'
  end
end
