# frozen_string_literal: true

require_relative 'cli_test_case'

# Preserve evaluation order and backend decisions while reporting structural review findings.
class CliFlowTest < CliTestCase
  def test_branch_order_fails_without_rewriting_conditions_with_fix
    assert_review_source(fixture(:code), 'project_positive_flow')
  end

  def test_validation_structure_checks_enclosing_blocks_without_rewriting_them
    code = fixture(:code)
    options = ['--only-checks', 'project_positive_flow']
    assert_review_source(code, 'project_positive_flow', count: 2, options: options)
    assert_includes @output, 'no implementation may follow'
    corrected = code.sub("  notify { 'outside-validation': }\n", '')
    write_source(corrected.sub("      notice('Valid')", fixture(:corrected)))
    assert_cli_success(*options, @file)
  end

  def test_monitoring_backend_check_does_not_rewrite_backend_conditions_with_fix
    code = fixture(:code)
    assert_review_source(code, 'project_monitoring_backend')
    write_source(code.sub("== 'synthetic_backend'", "!= 'none'"))
    assert_cli_success(@file)
  end

  def test_class_check_reuse_does_not_change_evaluation_order_with_fix
    fixture(:declarations2).each do |body|
      assert_review_source("class example { #{body} }\n", 'project_class_check_reuse',
                           options: ['--only-checks', 'project_class_check_reuse'])
    end
  end
end
