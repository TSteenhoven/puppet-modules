# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'guarded_packages_support'

# Exercise file writes, exit codes, suppressions and all enabled checks through the native CLI.
class CliGuardedPackagesTest < Minitest::Test
  include LintCliSupport
  include GuardedPackagesSupport

  def test_all_enabled_checks_accept_generated_code_and_preserve_upstream_fixes
    write_source(fixture('guarded_packages/before'), path: 'example/manifests/init.pp')
    assert_cli_failure(@file)
    assert_equal fixture('guarded_packages/before'), source
    capture_cli('--fix', @file)
    assert_equal fixture('guarded_packages/after'), source, @output + @errors
    assert_equal 1, diagnostics(@output, 'project_guarded_packages').length
    assert_cli_stable(fixture('guarded_packages/after'))
  end

  def test_only_check_fix_is_successful_and_idempotent
    write_source(pair)
    assert_cli_failure('--only-checks=project_guarded_packages', @file)
    assert_cli_success('--fix', '--only-checks=project_guarded_packages', @file)
    assert_equal merged, source
    assert_cli_stable(merged, '--only-checks=project_guarded_packages')
  end

  def test_upstream_whitespace_fixes_do_not_delay_the_merge_until_a_second_run
    code = fixture('guarded_packages/before').gsub(/^  /, "\t").gsub("}\n", "}  \n")
    write_source(code, path: 'example/manifests/init.pp')
    capture_cli('--fix', @file)
    assert_equal fixture('guarded_packages/after'), source, @output + @errors
    assert_cli_stable(fixture('guarded_packages/after'))
  end

  def test_unsafe_group_and_suppression_preserve_the_file
    options = ['--only-checks=project_guarded_packages']
    code = pair('ensure => installed, require => Package["synthetic"],')
    assert_review_source(code, 'project_guarded_packages', options: options)
    write_source("# lint:ignore:project_guarded_packages\n#{pair}# lint:endignore\n")
    original = source
    assert_cli_success('--fix', *options, @file)
    assert_equal original, source
  end
end
