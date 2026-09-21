# frozen_string_literal: true

require_relative 'test_helper'

# Equivalent resource lists share one rule while distinct resource types retain their own titles.
class ResourceTitleScopeTest < Minitest::Test
  include LintTestSupport

  RULE = :project_resource_list_reuse

  def test_declarations_and_references_of_each_resource_type
    %w[file service exec package example::item class].each do |type|
      reference = type.split('::').map(&:capitalize).join('::')
      code = "class example { #{type} { ['alpha', 'beta']: }\n" \
             "notify { 'consumer': require => #{reference}['beta', 'alpha'] } }"
      assert_preserved code, [:warning], review: true
    end
  end

  def test_full_extensions_and_near_matches_apply_to_file_declarations
    ["'/a', '/b', '/c', '/d', '/e', '/extra'", "'/a', '/b', '/c', '/d', '/other'"].each do |titles|
      code = "file { ['/a', '/b', '/c', '/d', '/e']: }\nnotify { 'consumer': require => File[#{titles}] }"
      assert_preserved code, [:warning], review: true
    end
  end

  def test_distinct_types_partial_overlap_and_single_titles_are_independent
    ["file { ['alpha', 'beta']: }\n$refs = Service['alpha', 'beta']",
     "$files = File['alpha', 'beta']\n$services = Service['alpha', 'beta']",
     "ensure_packages(['alpha', 'beta'])\n$files = File['alpha', 'beta']",
     "file { ['/a', '/b', '/c']: }\n$files = File['/a', '/b', '/d']",
     "file { ['/a', '/b', '/c']: }\n$files = File['/a', '/b']",
     "$one = Service['single']\n$two = Service['single']"].each { |code| assert_clean_passes code }
  end

  def test_repeated_reference_and_conditional_declaration_lists
    assert_preserved "$one = File['/a', '/b']\n$two = File['/b', '/a']", [:warning], review: true
    code = "if $enabled { service { ['alpha', 'beta']: enable => true } } " \
           "else { service { ['beta', 'alpha']: enable => false } }"
    assert_preserved code, [:warning], review: true
  end

  def test_shared_declaration_titles_and_local_aliases_are_clean
    code = <<~PUPPET
      class example {
        $paths = ['/a', '/b']
        $alias = $paths
        file { $paths: }
        $required_paths = concat($alias, ['/c'])
        notify { 'consumer': require => File[$required_paths] }
      }
    PUPPET
    assert_clean_passes code
  end

  def test_datatypes_and_indexing_are_not_resource_references
    ["type Example::Choice = Enum['alpha', 'beta']\n$one = Example::Choice['alpha', 'beta']\n" \
     "$two = Example::Choice['alpha', 'beta']",
     "$one = Enum['alpha', 'beta']\n$two = Enum['alpha', 'beta']",
     "$one = $data['alpha', 'beta']\n$two = $data['alpha', 'beta']"].each { |code| assert_clean_passes code }
  end
end
