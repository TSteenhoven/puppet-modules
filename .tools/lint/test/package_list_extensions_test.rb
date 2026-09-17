# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'resource_list_reuse_support'

# Package-name extensions stay separate from resource-reference composition.
class PackageListExtensionsTest < Minitest::Test
  include LintTestSupport
  include ResourceListReuseSupport

  def extended_pair(extra)
    shared_pair.gsub('required_packages', 'packages').sub('Package[$packages]', 'Package[$required_packages]').sub(
      '  # Order', <<~PUPPET.lines.map { |line| line.strip.empty? ? line : "  #{line}" }.join.chomp
        # Include the additional package prerequisites for these resources.
        $required_packages = concat(
          $packages,
          [#{extra}],
        )

        # Order
      PUPPET
    )
  end

  def test_one_and_multiple_additional_packages
    ["'delta'", "'delta', 'epsilon'"].each do |extra|
      before = pair("['alpha', 'beta', 'gamma']", "'alpha', 'beta', 'gamma', #{extra}")
      assert_fix before, extended_pair(extra), count: 1
    end
  end

  def test_additional_references_and_existing_reference_arrays_stay_outside_package_names
    before = pair("['alpha', 'beta', 'gamma']", "'alpha', 'beta', 'gamma', 'server'")
    before = before.sub('require => Package[', 'require => concat([Package[').sub("'server'],",
                                                                                  "'server']], $admin_require),")
    expected = extended_pair("'server'").sub('require => Package[$required_packages],',
                                             'require => concat(Package[$required_packages], $admin_require),')
    assert_fix before, expected, RULE, :project_resource_references
  end

  def test_exact_dependencies_share_the_base_of_an_extended_group
    before = pair("['alpha', 'beta', 'gamma']", "'alpha', 'beta', 'gamma', 'server'")
    before = before.sub("\n}", "\n  notify { 'base': require => Package['alpha', 'beta', 'gamma'] }\n}")
    expected = extended_pair("'server'").sub("\n}", "\n  notify { 'base': require => Package[$packages] }\n}")
    assert_fix before, expected
  end

  def test_multiple_different_extensions_and_name_collisions_require_review
    before = pair("['alpha', 'beta', 'gamma']", "'alpha', 'beta', 'gamma', 'server'")
    ambiguous = before.sub("\n}", "\n  notify { 'other': require => Package['alpha', 'beta', 'gamma', 'other'] }\n}")
    assert_preserved ambiguous, [:warning], review: true
    %w[packages required_packages].each do |name|
      code = before.sub('class example {', "class example (Array $#{name} = []) {")
      assert_preserved code, [:warning], review: true
    end
  end
end
