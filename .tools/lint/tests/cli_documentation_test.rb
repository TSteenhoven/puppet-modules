# frozen_string_literal: true

require_relative 'test_helper'

# Verify documentation corrections together with standard native checks.
class CliDocumentationTest < Minitest::Test
  include LintCliSupport

  def test_documentation_fix_works_with_standard_checks_and_preserves_code_fixes
    write_source(fixture('cli_documentation/and_preserves_code_fixes_code'), path: 'example/manifests/init.pp')
    assert_cli_success('--fix', @file)
    fixed = source
    refute_includes fixed, 'lint:ignore:140chars'
    assert_includes fixed, "$value = 'synthetic'"
    assert_includes fixed, "# @example Include the class\n#   include example\n"
    assert_cli_success('--fix', @file)
    assert_equal fixed, source
    assert_empty diagnostics(@output, 'project_documentation_layout')
  end

  def test_documentation_fix_requires_a_rescan_for_original_standard_length_findings
    code = fixture('cli_documentation/original_standard_length_findings_code')
    write_source(code, path: 'example/manifests/init.pp')
    assert_cli_failure('--fix', @file)
    assert_equal 1, diagnostics(@output, '140chars').length
    refute_equal code, source
    assert_cli_success(@file)
    assert_empty diagnostics(@output, 'project_documentation_layout')
  end

  def test_scoped_documentation_fix_keeps_unsafe_summary_and_fails
    code = "# @summary #{('A description with a default. ' * 6).strip}\nclass example {}\n"
    write_source(code)
    assert_cli_failure('--only-checks', 'project_documentation_layout', '--fix', @file)
    assert_includes @output, '[review]'
    assert_equal code, source
  end
end
