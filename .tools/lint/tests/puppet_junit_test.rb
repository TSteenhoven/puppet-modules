# frozen_string_literal: true

require_relative 'test_helper'
require 'project_lint/puppet_junit'
require 'stringio'

# Verify report identities, escaping and failures without reimplementing lint detection.
class PuppetJunitTest < Minitest::Test
  def convert(data)
    @xml = StringIO.new
    @console = StringIO.new
    @errors = StringIO.new
    ProjectLint::PuppetJunit.convert(StringIO.new(data), @xml, @console, @errors)
  end

  def problem(**overrides)
    { path: 'manifests/site.pp', check: 'project_arrays', kind: 'warning',
      message: 'Use concat', line: 1, column: 10 }.merge(overrides)
  end

  def test_clean_scan_has_a_passing_summary_without_inventing_per_file_test_results
    assert_equal 0, convert('[[], []]')
    assert_includes @xml.string, 'tests="1" failures="0" errors="0"'
    assert_includes @xml.string, 'name="Puppet lint scan"'
    refute_includes @xml.string, '<failure'
    assert_includes @console.string, 'no active findings'
  end

  def test_repeated_findings_share_one_case_and_keep_all_locations
    data = [[problem, problem(line: 2), problem(path: 'manifests/other.pp')]]
    assert_equal 0, convert(JSON.generate(data))
    xml = @xml.string
    assert_includes xml, 'tests="2" failures="2" errors="0"'
    assert_equal 1, xml.scan('name="manifests/site.pp:project_arrays"').length
    [1, 2].each do |line|
      assert_includes xml, "manifests/site.pp:#{line}:10: project_arrays: warning: Use concat"
    end
    assert_equal 3, @console.string.count("\n")
  end

  def test_xml_escapes_paths_messages_and_preserves_unicode
    data = [[problem(path: 'a&"<b>.pp', message: "Use <concat> & 'é'\nSecond line", kind: 'error')]]
    assert_equal 0, convert(JSON.generate(data))
    assert_includes @xml.string, 'file="a&amp;&quot;&lt;b&gt;.pp"'
    assert_includes @xml.string, "Use &lt;concat&gt; &amp; 'é'\nSecond line"
    refute_includes @xml.string, '<concat>'
  end

  def test_suppressed_and_fixed_findings_are_not_reported_as_failures
    data = [[problem(kind: 'ignored'), problem(kind: 'fixed')]]
    assert_equal 0, convert(JSON.generate(data))
    assert_includes @xml.string, 'failures="0"'
    refute_includes @xml.string, '<failure'
  end

  def test_extra_native_context_is_not_copied_into_reports_or_console
    assert_equal 0, convert(JSON.generate([[problem(context: 'synthetic-source-context')]]))
    refute_includes @xml.string, 'synthetic-source-context'
    refute_includes @console.string, 'synthetic-source-context'
  end

  def test_invalid_or_empty_input_is_a_report_error_not_a_passing_scan
    ['', '[]', '{}', '[null]', '[[{}]]', '[[null]]', '[[[]]]', '{"synthetic_context":'].each do |data|
      assert_equal 1, convert(data), data
      assert_includes @xml.string, 'errors="1"'
      assert_includes @xml.string, '<error type="ReportError">'
      refute_includes @xml.string, 'synthetic_context'
      refute_empty @errors.string
    end
  end

  def test_invalid_diagnostic_fields_fail_clearly
    [{ kind: 'unknown' }, { line: -1 }, { column: nil }, { message: [] }].each do |override|
      assert_equal 1, convert(JSON.generate([[problem(**override)]]))
      assert_includes @xml.string, 'Invalid Puppet-lint diagnostic'
    end
  end

  def test_failed_conversion_replaces_a_previous_report_and_output_errors_fail
    Dir.mktmpdir('junit-report-') do |directory|
      path = File.join(directory, 'report.xml')
      File.write(path, 'stale passing report')
      assert_equal 1, run_report([path], '')
      assert_includes File.read(path), '<error type="ReportError">'
      refute_includes File.read(path), 'stale'
      assert_equal 1, run_report([directory], '[[]]')
      assert_includes @errors.string, 'Cannot write'
    end
  end

  def test_missing_or_extra_output_arguments_fail_with_usage
    [[], %w[first.xml second.xml]].each do |arguments|
      assert_equal 1, run_report(arguments, '[[]]')
      assert_includes @errors.string, 'Usage:'
    end
  end

  def run_report(arguments, input)
    @errors = StringIO.new
    ProjectLint::PuppetJunit.run(arguments, input: StringIO.new(input), console: StringIO.new, errors: @errors)
  end
end
