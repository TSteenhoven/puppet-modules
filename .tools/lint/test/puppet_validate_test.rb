# frozen_string_literal: true

require_relative 'test_helper'
require 'project_lint/puppet_validate'
require 'rexml/document'
require 'stringio'

# Selection and report failures must not produce a passing or stale validation report.
class PuppetValidateTest < Minitest::Test
  include LintCliSupport

  def run_report(*paths)
    @report = File.join(@directory, 'results', 'puppet.xml')
    @console = StringIO.new
    @errors = StringIO.new
    @result = ProjectLint::PuppetValidate.run([@report, *paths], console: @console, errors: @errors)
    REXML::Document.new(File.read(@report)).root.elements['testsuite']
  end

  def test_empty_selection_creates_an_error_report_and_replaces_previous_results
    write_file('results/puppet.xml', '<stale-passing-report/>')
    suite = run_report
    assert_equal 1, @result
    assert_equal '1', suite.attributes['errors']
    assert_equal 'No Puppet manifests selected.', suite.elements['testcase/error'].text
    assert_includes @console.string, 'No Puppet manifests selected.'
    refute_includes File.read(@report), 'stale-passing-report'
  end

  def test_missing_files_directories_and_other_formats_are_errors
    other = write_file('other.txt', '$value = 1')
    suite = run_report(File.join(@directory, 'missing.pp'), @directory, other)
    assert_equal 1, @result
    assert_equal '3', suite.attributes['tests']
    assert_equal '3', suite.attributes['errors']
    assert_equal '0', suite.attributes['failures']
    assert_equal 3, suite.get_elements('testcase/error').length
  end

  def test_equivalent_paths_are_validated_once_and_create_the_report_directory
    path = write_file('manifest with spaces & é.pp', '$value = "synthetic"')
    suite = run_report(path, File.join(@directory, '.', File.basename(path)))
    assert_equal 0, @result, @console.string
    assert_equal(%w[1 0 0], %w[tests failures errors].map { |key| suite.attributes[key] })
    assert_includes suite.elements['testcase'].attributes['file'], 'manifest with spaces & é.pp'
  end

  def test_usage_and_output_errors_fail_without_modifying_manifests
    path = write_file('site.pp', '$value = 1')
    [[], [path]].each do |arguments|
      errors = StringIO.new
      assert_equal 1, ProjectLint::PuppetValidate.run(arguments, errors: errors)
      assert_includes errors.string, 'Usage:'
    end
    assert_equal '$value = 1', File.read(path)
    errors = StringIO.new
    assert_equal 1, ProjectLint::PuppetValidate.run([File.join(path, 'report.xml'), path], errors: errors)
    assert_includes errors.string, 'Cannot write'
  end
end
