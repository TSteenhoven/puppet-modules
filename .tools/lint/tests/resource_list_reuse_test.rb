# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'resource_list_reuse_support'

# Detection compares origins and scopes without evaluating functions or guessing package intent.
class ResourceListReuseTest < Minitest::Test
  include LintTestSupport
  include ResourceListReuseSupport

  def test_exact_lists_and_permutations_are_one_finding
    ["'alpha', 'beta', 'gamma'", "'gamma', 'alpha', 'beta'"].each do |dependency|
      assert_equal [:warning], finding_kinds(pair("['alpha', 'beta', 'gamma']", dependency))
    end
  end

  def test_all_relationship_attributes_and_additional_packages
    %w[require before notify subscribe].each do |attribute|
      code = pair("['alpha', 'beta', 'gamma']", "'alpha', 'beta', 'delta', 'gamma'", attribute: attribute)
      assert_equal [:warning], finding_kinds(code)
    end
  end

  def test_multiple_resources_form_one_group
    code = pair.sub("  }\n}", "  }\n  notify { 'other': require => Package['alpha', 'beta', 'gamma'] }\n}")
    assert_equal [:warning], finding_kinds(code)
  end

  def test_repeated_installations_and_repeated_references
    code = "class example { ensure_packages(['alpha', 'beta'])\nensure_packages(['beta', 'alpha']) }"
    assert_equal [:warning], finding_kinds(code)
    assert_equal [:warning],
                 finding_kinds("class example { $one = Package['alpha', 'beta']\n$two = Package['beta', 'alpha'] }")
  end

  def test_existing_variable_and_extensions_reuse_the_same_origin
    [shared_pair, shared_pair.sub('Package[$required_packages]', "Package[$required_packages + ['delta']]"),
     shared_pair.sub('Package[$required_packages]', "Package[concat($required_packages, ['delta'])]")].each do |code|
      assert_clean_passes code
    end
    code = shared_pair.sub('  # Order', "  $extended = concat($required_packages, ['delta'])\n\n  # Order")
    assert_clean_passes code.sub('Package[$required_packages]', 'Package[$extended]')
  end

  def test_a_different_variable_name_is_accepted
    assert_clean_passes shared_pair.gsub('required_packages', 'context_tools')
  end

  def test_redeclaring_the_literal_behind_a_variable_is_reported
    code = shared_pair.sub('Package[$required_packages]', "Package['alpha', 'beta', 'gamma']")
    assert_preserved code, [:warning], review: true
    code = pair.sub('  # Install', "  $dependencies = ['alpha', 'beta', 'gamma']\n\n  # Install")
    assert_preserved code.sub("Package['alpha', 'beta', 'gamma']", 'Package[$dependencies]'), [:warning], review: true
  end

  def test_small_partial_overlap_and_dependency_subsets_are_not_duplicates
    ["'alpha', 'beta', 'delta'", "'alpha', 'beta'", "'delta', 'epsilon'"].each do |dependency|
      assert_clean_passes pair("['alpha', 'beta', 'gamma']", dependency)
    end
  end

  def test_large_near_matches_require_review
    code = pair("['alpha', 'beta', 'delta', 'epsilon', 'gamma']", "'alpha', 'beta', 'delta', 'epsilon', 'zeta'")
    assert_preserved code, [:warning], review: true
  end
end
