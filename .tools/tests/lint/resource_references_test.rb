require_relative 'test_helper'

class ResourceReferencesTest < Minitest::Test
  include LintTestSupport

  def lint(code, fix: false)
    lint_checks(code, [:project_resource_references], fix: fix)
  end

  def assert_fix(before, after, count: 1)
    problems, unchanged = lint(before)
    assert_equal before, unchanged
    assert_equal Array.new(count, :warning), problems.map { |problem| problem[:kind] }
    problems, fixed = lint(before, fix: true)
    assert_equal Array.new(count, :fixed), problems.map { |problem| problem[:kind] }
    assert_equal after, fixed
    ProjectLint::Model.new(fixed)
    assert_empty lint(fixed).first
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

  def test_correct_references_keep_their_formatting
    assert_unchanged("Notify['target'] -> [Package['alpha', 'bravo', 'charlie'], Service['example']]\n")
    assert_unchanged("Notify['target'] -> File[\n  '/etc/a.conf',\n  '/etc/z.conf',\n]\n")
    assert_unchanged("Notify['target'] -> Package['example']\n")
  end

  def test_service_file_class_and_arbitrary_defined_types
    {
      'Service' => %w[apache2 nginx],
      'File' => ['/etc/a.conf', '/etc/z.conf'],
      'Class' => %w[alpha zulu],
      'Example::Widget' => %w[alpha zulu],
      'Custom_type' => %w[alpha zulu],
    }.each do |type, (first, last)|
      assert_fix("Notify['target'] -> [#{type}['#{last}'], #{type}['#{first}']]\n",
                 "Notify['target'] -> #{type}['#{first}', '#{last}']\n")
    end
  end

  def test_different_types_and_nonadjacent_references_stay_separate
    assert_unchanged("Notify['target'] -> [Package['zulu'], Service['nginx'], Package['alpha']]\n")
    assert_unchanged("Notify['target'] -> [Package['zulu'], $extra, Package['alpha']]\n")
  end

  def test_multiple_independent_groups
    assert_fix("Notify['target'] -> [Package['z'], Package['a'], File['/z'], File['/a'], Package['b']]\n",
               "Notify['target'] -> [Package['a', 'z'], File['/a', '/z'], Package['b']]\n", count: 2)
  end

  def test_resource_type_case_does_not_split_a_group
    assert_fix("Notify['target'] -> [Example::Widget['z'], Example::WIDGET['a']]\n",
               "Notify['target'] -> Example::Widget['a', 'z']\n")
  end

  def test_identical_references_in_different_positions_are_each_checked
    assert_fix("Notify['target'] -> [File['z', 'a']]\nNotify['other'] -> File['z', 'a']\n",
               "Notify['target'] -> File['a', 'z']\nNotify['other'] -> File['a', 'z']\n", count: 2)
  end

  def test_multiline_groups_remove_the_outer_array_and_its_trailing_comma
    assert_fix("Notify['target'] -> [\n  File['/z'],\n  File['/b', '/a'],\n]\n",
               "Notify['target'] -> File[\n  '/a',\n  '/b',\n  '/z',\n]\n")
  end

  def test_multiline_sort_preserves_whitespace_slots
    assert_fix("Notify['target'] -> File[\n  '/z',\n  '/a',\n  '/b',\n]\n",
               "Notify['target'] -> File[\n  '/a',\n  '/b',\n  '/z',\n]\n")
  end

  def test_metaparameters_and_relationship_lists
    %w[require before notify subscribe].each do |attribute|
      assert_fix("notify { 'example': #{attribute} => [Service['nginx'], Service['apache2']] }\n",
                 "notify { 'example': #{attribute} => Service['apache2', 'nginx'] }\n")
    end
    assert_fix("[File['/z'], File['/a']] -> Service['z', 'a']\n",
               "File['/a', '/z'] -> Service['a', 'z']\n", count: 2)
  end

  def test_single_reference_arrays_are_unwrapped_in_every_metaparameter
    %w[require before notify subscribe].each do |attribute|
      ["Package['a', 'b']", "Service['example']", "Class['example']", "Example::Widget[$title]",
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
    assert_fix("notify { 'example':\n  require => [\n    Package[\n      'a',\n      'b',\n    ],\n  ],\n}\n",
               "notify { 'example':\n  require => Package[\n    'a',\n    'b',\n  ],\n}\n")
    assert_fix("Notify['target'] -> [\n  File['line one\n  line two'],\n]\n",
               "Notify['target'] -> File['line one\n  line two']\n")
  end

  def test_unwrapping_preserves_comments_suppressions_and_heredocs
    [
      "Notify['target'] -> [ # Keep this explanation.\n  Package['a', 'b'],\n]\n",
      "Notify['target'] -> [\n  Package['a', 'b'], # Keep this explanation.\n]\n",
      "Notify['target'] -> [\n  Package['a', 'b'],\n] # lint:ignore:project_resource_references\n",
      "Notify['target'] -> [File[@(TEXT)]]\n/tmp/example\nTEXT\n",
    ].each do |code|
      problems, fixed = lint(code, fix: true)
      assert_equal [:warning], problems.map { |problem| problem[:kind] }
      assert_includes problems.first[:message], '[review]'
      assert_equal code, fixed
    end
    code = "# lint:ignore:project_resource_references\nNotify['target'] -> [Package['a', 'b']]\n# lint:endignore\n"
    problems, fixed = lint(code, fix: true)
    assert_equal [:ignored], problems.map { |problem| problem[:kind] }
    assert_equal code, fixed
  end

  def test_single_reference_arrays_outside_relationship_consumers_are_unchanged
    [
      "$refs = [Package['a', 'b']]\n",
      "example::call([Package['a', 'b']])\n",
      "$ref = [Package['a', 'b']][0]\n",
      "notify { 'example': message => [Package['a', 'b']] }\n",
      "$refs = Notify['target'] -> [Package['a', 'b']]\n",
      "Notify['target'] -> [[Package['a', 'b']]]\n",
      "Notify['target'] -> [Package['a', 'b'], Service['example']]\n",
    ].each { |code| assert_unchanged(code) }
  end

  def test_function_arguments_relationship_chains_and_nested_arrays_keep_their_structure
    assert_unchanged("example::call(Package['z'], Package['a'])\n")
    %w[-> ~> <- <~].each { |operator| assert_unchanged("Package['z'] #{operator} Package['a']\n") }
    assert_unchanged("Notify['target'] -> [[Package['z']], [Package['a']]]\n")
    assert_fix("Notify['target'] -> [[Package['z'], Package['a']], Package['b']]\n",
               "Notify['target'] -> [[Package['a', 'z']], Package['b']]\n")
  end

  def test_data_types_and_lookups_are_not_resource_references
    assert_unchanged("$types = [Enum['z', 'a'], Enum['b', 'a'], Pattern[/z/, /a/]]\n")
    assert_unchanged("$value = $lookup['z', 'a']\n")
    assert_unchanged("$types = [Timestamp['z', 'a'], Timespan['z', 'a'], Resource['file', '/tmp/a']]\n")
    assert_unchanged("type Example::Choice = Enum['z', 'a']\n$value = Example::Choice['z', 'a']\n")
  end

  def test_comments_and_dynamic_titles_require_manual_merging
    [
      "Notify['target'] -> [Package['z'], # Keep this explanation.\n  Package['a']]\n",
      "Notify['target'] -> File['/z', /* Keep this explanation. */ '/a']\n",
      %q{Notify['target'] -> [File[$path], File["${root}/a"]]} + "\n",
      "Notify['target'] -> [File[join($parts, '/')], File['/a']]\n",
    ].each do |code|
      problems, fixed = lint(code, fix: true)
      assert_equal [:warning], problems.map { |problem| problem[:kind] }
      assert_includes problems.first[:message], '[review]'
      assert_equal code, fixed
    end
    assert_unchanged(%q{Notify['target'] -> File[$path, "${root}/a"]} + "\n")
  end

  def test_trailing_comment_is_preserved
    assert_fix("Notify['target'] -> [Package['z'], Package['a']] # Keep the outer explanation.\n",
               "Notify['target'] -> Package['a', 'z'] # Keep the outer explanation.\n")
  end

  def test_sort_uses_literal_values_and_preserves_quotes_escapes_and_duplicates
    assert_fix(%q{Notify['target'] -> File['z', "a\tb", 'a b', 'a b']} + "\n",
               %q{Notify['target'] -> File["a\tb", 'a b', 'a b', 'z']} + "\n")
    assert_fix("Notify['target'] -> [Package[zulu], Package[alpha]]\n", "Notify['target'] -> Package[alpha, zulu]\n")
    assert_fix("Notify['target'] -> File['z', 'B', 'a']\n", "Notify['target'] -> File['B', 'a', 'z']\n")
  end

  def test_unicode_positions_and_titles
    assert_fix("Notify['target'] -> ['é', File['é', 'b', 'a']]\n", "Notify['target'] -> ['é', File['a', 'b', 'é']]\n")
  end

  def test_strings_and_comments_are_not_code
    assert_unchanged(%q{$text = "Package['z'], Package['a']"} + "\n# File['/z', '/a']\n")
    assert_unchanged("$text = @(TEXT)\nFile['z', 'a']\nTEXT\n")
  end

  def test_diagnostic_location_and_message_do_not_expose_titles
    problems, = lint("Notify['target'] -> [\n  Package['synthetic-z'],\n  Package['synthetic-a'],\n]\n")
    assert_equal [[2, 3]], problems.map { |problem| problem.values_at(:line, :column) }
    refute_includes problems.first[:message], 'synthetic'
  end

  def test_ordinary_values_and_observable_relationship_results_are_not_rewritten
    [
      "$refs = [Package['z'], Package['a']]\n",
      "$refs = File['z', 'a']\n",
      "$first = File['z', 'a'][0]\n",
      "example::call(File['z', 'a'])\n",
      "$refs = Notify['target'] -> [File['z'], File['a']]\n",
      "$refs = [1].map |$item| { Notify['target'] -> File['z', 'a'] }\n",
      "$refs = { 'require' => [File['z'], File['a']] }\n",
    ].each do |code|
      problems, fixed = lint(code, fix: true)
      assert_equal [:warning], problems.map { |problem| problem[:kind] }
      assert_includes problems.first[:message], '[review]'
      assert_equal code, fixed
    end
  end
end
