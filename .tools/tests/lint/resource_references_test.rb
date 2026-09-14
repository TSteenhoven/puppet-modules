require_relative 'test_helper'

class ResourceReferencesTest < Minitest::Test
  def lint(code, fix: false)
    checks = PuppetLint::Checks.new
    checks.load_data('example.pp', code)
    check = PuppetLint.configuration.check_object.fetch(:project_resource_references).new
    problems = check.run
    check.fix_problems if fix
    [problems, checks.manifest]
  end

  def assert_fix(before, after, count: 1)
    problems, unchanged = lint(before)
    assert_equal before, unchanged
    assert_equal Array.new(count, :warning), problems.map { |problem| problem[:kind] }
    problems, fixed = lint(before, fix: true)
    assert_equal Array.new(count, :fixed), problems.map { |problem| problem[:kind] }
    assert_equal after, fixed
    problems, second_pass = lint(fixed, fix: true)
    assert_empty problems
    assert_equal fixed, second_pass
  end

  def assert_unchanged(code)
    problems, fixed = lint(code, fix: true)
    assert_empty problems
    assert_equal code, fixed
  end

  def test_two_package_references
    assert_fix("$refs = [Package['console-setup'], Package['keyboard-configuration']]\n",
               "$refs = [Package['console-setup', 'keyboard-configuration']]\n")
  end

  def test_multiple_references_and_titles_are_sorted_together
    assert_fix("$refs = [Package['zulu', 'charlie'], Package['bravo'], Package['alpha', 'delta']]\n",
               "$refs = [Package['alpha', 'bravo', 'charlie', 'delta', 'zulu']]\n")
  end

  def test_unsorted_combined_reference
    assert_fix("$refs = Package['keyboard-configuration', 'console-setup']\n",
               "$refs = Package['console-setup', 'keyboard-configuration']\n")
  end

  def test_correct_references_keep_their_formatting
    assert_unchanged("$refs = [Package['alpha', 'bravo', 'charlie'], Service['example']]\n")
    assert_unchanged("$refs = File[\n  '/etc/a.conf',\n  '/etc/z.conf',\n]\n")
    assert_unchanged("$refs = Package['example']\n")
  end

  def test_service_file_class_and_arbitrary_defined_types
    {
      'Service' => %w[apache2 nginx],
      'File' => ['/etc/a.conf', '/etc/z.conf'],
      'Class' => %w[alpha zulu],
      'Example::Widget' => %w[alpha zulu],
      'Custom_type' => %w[alpha zulu],
    }.each do |type, (first, last)|
      assert_fix("$refs = [#{type}['#{last}'], #{type}['#{first}']]\n",
                 "$refs = [#{type}['#{first}', '#{last}']]\n")
    end
  end

  def test_different_types_and_nonadjacent_references_stay_separate
    assert_unchanged("$refs = [Package['zulu'], Service['nginx'], Package['alpha']]\n")
    assert_unchanged("$refs = [Package['zulu'], $extra, Package['alpha']]\n")
  end

  def test_multiple_independent_groups
    assert_fix("$refs = [Package['z'], Package['a'], File['/z'], File['/a'], Package['b']]\n",
               "$refs = [Package['a', 'z'], File['/a', '/z'], Package['b']]\n", count: 2)
  end

  def test_resource_type_case_does_not_split_a_group
    assert_fix("$refs = [Example::Widget['z'], Example::WIDGET['a']]\n",
               "$refs = [Example::Widget['a', 'z']]\n")
  end

  def test_identical_references_in_different_positions_are_each_checked
    assert_fix("$refs = [File['z', 'a']]\n$other = File['z', 'a']\n",
               "$refs = [File['a', 'z']]\n$other = File['a', 'z']\n", count: 2)
  end

  def test_multiline_groups_keep_outer_array_and_trailing_comma
    assert_fix("$refs = [\n  File['/z'],\n  File['/b', '/a'],\n]\n",
               "$refs = [\n  File[\n    '/a',\n    '/b',\n    '/z',\n  ],\n]\n")
  end

  def test_multiline_sort_preserves_whitespace_slots
    assert_fix("$refs = File[\n  '/z',\n  '/a',\n  '/b',\n]\n",
               "$refs = File[\n  '/a',\n  '/b',\n  '/z',\n]\n")
  end

  def test_metaparameters_and_relationship_lists
    %w[require before notify subscribe].each do |attribute|
      assert_fix("notify { 'example': #{attribute} => [Service['nginx'], Service['apache2']] }\n",
                 "notify { 'example': #{attribute} => [Service['apache2', 'nginx']] }\n")
    end
    assert_fix("[File['/z'], File['/a']] -> Service['z', 'a']\n",
               "[File['/a', '/z']] -> Service['a', 'z']\n", count: 2)
  end

  def test_function_arguments_relationship_chains_and_nested_arrays_keep_their_structure
    assert_unchanged("example::call(Package['z'], Package['a'])\n")
    %w[-> ~> <- <~].each { |operator| assert_unchanged("Package['z'] #{operator} Package['a']\n") }
    assert_unchanged("$refs = [[Package['z']], [Package['a']]]\n")
    assert_fix("$refs = [[Package['z'], Package['a']], Package['b']]\n",
               "$refs = [[Package['a', 'z']], Package['b']]\n")
  end

  def test_data_types_and_lookups_are_not_resource_references
    assert_unchanged("$types = [Enum['z', 'a'], Enum['b', 'a'], Pattern[/z/, /a/]]\n")
    assert_unchanged("$value = $lookup['z', 'a']\n")
    assert_unchanged("$types = [Timestamp['z', 'a'], Timespan['z', 'a'], Resource['file', '/tmp/a']]\n")
    assert_unchanged("type Example::Choice = Enum['z', 'a']\n$value = Example::Choice['z', 'a']\n")
  end

  def test_comments_and_dynamic_titles_require_manual_merging
    [
      "$refs = [Package['z'], # Keep this explanation.\n  Package['a']]\n",
      "$refs = File['/z', /* Keep this explanation. */ '/a']\n",
      '$refs = [File[$path], File["${root}/a"]]' + "\n",
      "$refs = [File[join($parts, '/')], File['/a']]\n",
    ].each do |code|
      problems, fixed = lint(code, fix: true)
      assert_equal [:warning], problems.map { |problem| problem[:kind] }
      assert_includes problems.first[:message], '[review]'
      assert_equal code, fixed
    end
    assert_unchanged('$refs = File[$path, "${root}/a"]' + "\n")
  end

  def test_trailing_comment_is_preserved
    assert_fix("$refs = [Package['z'], Package['a']] # Keep the outer explanation.\n",
               "$refs = [Package['a', 'z']] # Keep the outer explanation.\n")
  end

  def test_sort_uses_literal_values_and_preserves_quotes_escapes_and_duplicates
    assert_fix(%q{$refs = File['z', "a\tb", 'a b', 'a b']} + "\n",
               %q{$refs = File["a\tb", 'a b', 'a b', 'z']} + "\n")
    assert_fix("$refs = [Package[zulu], Package[alpha]]\n", "$refs = [Package[alpha, zulu]]\n")
    assert_fix("$refs = File['z', 'B', 'a']\n", "$refs = File['B', 'a', 'z']\n")
  end

  def test_unicode_positions_and_titles
    assert_fix("$refs = ['é', File['é', 'b', 'a']]\n", "$refs = ['é', File['a', 'b', 'é']]\n")
  end

  def test_strings_and_comments_are_not_code
    assert_unchanged(%q{$text = "Package['z'], Package['a']"} + "\n# File['/z', '/a']\n")
    assert_unchanged("$text = @(TEXT)\nFile['z', 'a']\nTEXT\n")
  end

  def test_diagnostic_location_and_message_do_not_expose_titles
    problems, = lint("$refs = [\n  Package['synthetic-z'],\n  Package['synthetic-a'],\n]\n")
    assert_equal [[2, 3]], problems.map { |problem| problem.values_at(:line, :column) }
    refute_includes problems.first[:message], 'synthetic'
  end
end
