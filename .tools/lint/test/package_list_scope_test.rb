# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'resource_list_reuse_support'

# Keep branch, variable and namespace boundaries separate during source discovery.
class PackageListScopeTest < Minitest::Test
  include LintTestSupport
  include ResourceListReuseSupport

  def test_separate_definitions_and_lambda_scopes_are_not_combined
    assert_clean_passes <<~PUPPET
      class first { ensure_packages(['alpha', 'beta']) }
      define second { notify { $title: require => Package['alpha', 'beta'] } }
      class third { ['one'].each |$item| { ensure_packages(['alpha', 'beta']) } }
    PUPPET
  end

  def test_conditional_literals_and_concat_are_reviewed_without_evaluation
    ["concat(['alpha', 'beta', 'gamma'], $extra)",
     "$enabled ? { true => ['alpha', 'beta', 'gamma'], default => [] }",
     "if $enabled { ['alpha', 'beta', 'gamma'] } else { [] }"].each do |expression|
      assert_preserved pair(expression), [:warning], review: true
    end
  end

  def test_variable_aliases_and_defaults_are_not_confused_with_duplicate_lists
    assert_clean_passes <<~PUPPET
      class example (Array[String] $packages = ['alpha', 'beta']) {
        ensure_packages($packages)
        notify { 'consumer': require => Package['alpha', 'beta'] }
      }
    PUPPET
    assert_clean_passes shared_pair.sub('  ensure_packages(', "  $alias = $required_packages\n  ensure_packages(")
                                   .sub('Package[$required_packages]', 'Package[$alias]')
  end

  def test_single_packages_unknown_functions_and_non_package_references_are_excluded
    assert_clean_passes pair("['alpha']", "'alpha'")
    assert_clean_passes pair.gsub('ensure_packages', 'other::ensure_packages').gsub('Package[', 'Service[')
    assert_clean_passes pair("lookup('synthetic', { 'default_value' => ['alpha', 'beta', 'gamma'] })")
  end

  def test_namespaced_calls_defines_and_top_level_examples_are_supported
    %w[::ensure_packages stdlib::ensure_packages ::stdlib::ensure_packages].each do |name|
      assert_equal [:warning], finding_kinds(pair.sub('ensure_packages', name).sub('class example', 'define example'))
    end
    assert_equal [:warning], finding_kinds(pair.delete_prefix("class example {\n").delete_suffix("}\n"))
  end

  def test_same_looking_conditional_sources_are_distinct
    code = <<~PUPPET
      class example {
        if $enabled { ensure_packages(['alpha', 'beta']) } else { ensure_packages(['alpha', 'beta']) }
      }
    PUPPET
    assert_preserved code, [:warning], review: true
  end

  def test_different_shared_sets_can_contain_common_tools
    assert_clean_passes <<~PUPPET
      class example {
        $first = ['alpha', 'beta', 'gamma']
        $second = ['alpha', 'beta', 'delta', 'epsilon', 'gamma']
        ensure_packages($first)
        ensure_packages($second)
        notify { 'first': require => Package[$first] }
        notify { 'second': require => Package[concat($second, ['zeta'])] }
      }
    PUPPET
  end
end
