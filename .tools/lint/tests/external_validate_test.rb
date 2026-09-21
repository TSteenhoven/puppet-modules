# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'
require 'rexml/document'

# Verify the packaged CLI against synthetic manifests in an independent consumer bundle.
class ExternalValidateTest < Minitest::Test
  include InstalledGemSupport

  def test_native_failures_keep_later_results_and_source_unchanged
    prepare_invalid_and_valid_manifests
    command('bundle', 'exec', 'puppet-validate-junit', '.tools/lint/results/puppet-validate-report.xml', *@paths)
    refute @status.success?, @output + @errors
    assert_mixed_results(report_suite)
    assert_includes @output, 'Syntax error'
    assert_equal "$value = [\n", read(@paths[0])
    assert_equal "fail('synthetic validation input')\n", read(@paths[1])
    assert_empty Dir[File.join(@project, '*.xml')]
  end

  def prepare_invalid_and_valid_manifests
    bad = 'manifests/invalid.pp'
    good = 'manifests/valid & é.pp'
    missing = 'manifests/missing.pp'
    write(bad, "$value = [\n")
    # Parsing must not evaluate this call or compile a catalog.
    write(good, "fail('synthetic validation input')\n")
    @paths = [bad, good, missing]
  end

  def report_suite
    REXML::Document.new(read('.tools/lint/results/puppet-validate-report.xml')).root.elements['testsuite']
  end

  def assert_mixed_results(suite)
    assert_equal 'puppet-validate', suite.attributes['name']
    assert_equal(%w[3 1 1], %w[tests failures errors].map { |key| suite.attributes[key] })
    cases = suite.get_elements('testcase').to_h { |item| [item.attributes['name'], item] }
    assert_equal @paths, cases.keys
    assert_case_outcomes(*cases.values)
  end

  def assert_case_outcomes(bad, good, missing)
    assert_includes bad.elements['failure'].text, 'Syntax error'
    assert_nil good.elements['failure']
    assert_nil good.elements['error']
    assert missing.elements['error']
  end

  def test_clean_run_replaces_failure_report_and_does_not_overwrite_other_reports
    report = '.tools/lint/results/puppet-validate-report.xml'
    write(report, '<stale-failure/>')
    other = '.tools/lint/results/puppet-lint-report.xml'
    write(other, 'synthetic other report')
    run_success('bundle', 'exec', 'puppet-validate-junit', report, 'manifests/site.pp',
                'modules/profile/manifests/init.pp')
    suite = report_suite
    assert_equal(%w[2 0 0], %w[tests failures errors].map { |key| suite.attributes[key] })
    assert_equal 'synthetic other report', read(other)
    refute File.exist?(File.join(@installed, 'results'))
  end
end
