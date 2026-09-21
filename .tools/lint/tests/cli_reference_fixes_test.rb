# frozen_string_literal: true

require_relative 'test_helper'

# Verify reference fixes, ordinary standard fixes and repeat execution through the CLI.
class CliReferenceFixesTest < Minitest::Test
  include LintCliSupport

  def test_resource_references_fix_works_with_standard_checks_and_is_idempotent
    write_source("Notify['target'] -> [Package[\"zulu\"], Service['nginx'], Package[\"alpha\"], Service['apache2']]\n",
                 path: 'references.pp')
    assert_cli_failure(@file)
    assert_equal 2, diagnostics(@output, 'project_resource_references').length
    assert_cli_success('--fix', @file)
    expected = "Notify['target'] -> [Package['alpha', 'zulu'], Service['apache2', 'nginx']]\n"
    assert_equal expected, source
    ProjectLint::Ast.new(source)
    assert_reference_rescan(expected)
  end

  def assert_reference_rescan(expected)
    assert_cli_success(@file)
    assert_empty @output
    assert_cli_success('--fix', @file)
    assert_empty diagnostics(@output, 'project_resource_references')
    assert_equal expected, source
  end

  def test_resource_references_fix_preserves_comments_and_keeps_the_warning
    assert_review_source(fixture('cli_reference_fixes/and_keeps_the_warning_code'), 'project_resource_references')
    assert_includes @output, '[review]'
  end

  def test_single_reference_array_is_removed_with_standard_fixes
    code = fixture('cli_reference_fixes/removed_with_standard_fixes_code')
    write_source(code)
    assert_cli_failure(@file)
    assert_equal 1, diagnostics(@output, 'project_resource_references').length
    assert_equal code, source
    assert_cli_success('--fix', @file)
    assert_equal "# Declare the example dependency.\nnotify { 'example':\n  require => Package['a', 'b'],\n}\n", source
    ProjectLint::Ast.new(source)
    assert_cli_stable("# Declare the example dependency.\nnotify { 'example':\n  require => Package['a', 'b'],\n}\n")
  end
end
