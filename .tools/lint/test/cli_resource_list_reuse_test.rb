# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'resource_list_reuse_support'

# Native writing, diagnostics and suppression handling remain owned by Puppet-lint.
class CliResourceListReuseTest < Minitest::Test
  include LintCliSupport
  include ResourceListReuseSupport

  def test_enabled_profile_and_upstream_quote_sort_and_wrapper_fixes
    code = documented_pair.sub("Package['alpha', 'beta', 'gamma']", '[Package["gamma", "beta", "alpha"]]')
    write_source(code, path: 'example/manifests/init.pp')
    expected = documented_pair(shared_pair)
    assert_cli_failure(@file)
    assert_equal code, source
    capture_cli('--fix', @file)
    assert_equal expected, source, @output + @errors
    assert_equal 1, diagnostics(@output, 'project_resource_list_reuse').length
    assert_cli_stable(expected)
  end

  def test_only_check_fix_and_suppression
    write_source(pair)
    assert_cli_failure('--only-checks=project_resource_list_reuse', @file)
    assert_cli_success('--fix', '--only-checks=project_resource_list_reuse', @file)
    assert_cli_stable(shared_pair, '--only-checks=project_resource_list_reuse')
    ignored = "# lint:ignore:project_resource_list_reuse\n#{pair}# lint:endignore\n"
    write_source(ignored)
    assert_cli_success('--fix', '--only-checks=project_resource_list_reuse', @file)
    assert_equal ignored, source
  end

  def test_review_findings_preserve_input_and_json_contains_no_source_objects
    code = pair("['alpha', 'beta', 'delta', 'epsilon', 'gamma']", "'alpha', 'beta', 'delta', 'epsilon', 'zeta'")
    assert_review_source(code, 'project_resource_list_reuse', options: ['--only-checks=project_resource_list_reuse'])
    capture_cli('--json', '--only-checks=project_resource_list_reuse', @file)
    problem = JSON.parse(@output).flatten.first
    assert_equal 'project_resource_list_reuse', problem.fetch('check')
    assert_includes problem.fetch('message'), '[review]'
    refute_match(/alpha|beta|delta|gamma|Puppet::/, @output)
  end

  def test_nested_package_composition_is_fixed_with_all_checks_enabled
    write_source(fixture('resource_dependencies/before'), path: 'example/manifests/init.pp')
    assert_cli_failure(@file)
    assert_cli_success('--fix', @file)
    assert_cli_stable(fixture('resource_dependencies/after'))
  end
end
