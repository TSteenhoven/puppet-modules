# frozen_string_literal: true

require_relative 'cli_test_case'

# Verify reference fixes, ordinary standard fixes and repeat execution through the CLI.
class CliReferenceFixesTest < CliTestCase
  def test_resource_references_fix_works_with_standard_checks_and_is_idempotent
    write_source(fixture(:sample), path: 'references.pp')
    assert_cli_failure(@file)
    assert_equal 2, diagnostics(@output, 'project_resource_references').length
    assert_cli_success('--fix', @file)
    expected = fixture(:expected)
    assert_equal expected, source
    ProjectLint::Model.new(source)
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
    assert_review_source(fixture(:code), 'project_resource_references')
    assert_includes @output, '[review]'
  end

  def test_single_reference_array_is_removed_with_standard_fixes
    code = fixture(:code)
    write_source(code)
    assert_cli_failure(@file)
    assert_equal 1, diagnostics(@output, 'project_resource_references').length
    assert_equal code, source
    assert_cli_success('--fix', @file)
    assert_equal fixture(:expected), source
    ProjectLint::Model.new(source)
    assert_cli_stable(fixture(:expected))
  end
end
