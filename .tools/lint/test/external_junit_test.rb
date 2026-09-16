# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'

# The packaged converter consumes one native scan without replacing its configuration or status.
class ExternalJunitTest < Minitest::Test
  include InstalledGemSupport

  def test_clean_and_failed_native_scans_keep_their_status
    @env['GITHUB_ACTION'] = 'synthetic_test'
    junit_pipeline
    assert @status.success?, @output + @errors
    assert_includes read('puppet.xml'), 'name="Puppet lint scan"'
    code = "$values = [1] + [2]\n$other = [3] + [4]\n"
    write('manifests/site.pp', code)
    junit_pipeline
    assert_findings_report
    assert_equal code, read('manifests/site.pp')
  end

  def assert_findings_report
    refute @status.success?
    report = read('puppet.xml')
    assert_includes report, 'name="manifests/site.pp:project_arrays"'
    assert_includes report, 'manifests/site.pp:2:'
    assert_includes @output, 'project_arrays: warning:'
  end

  def test_native_startup_failure_produces_a_report_error
    write('.puppet-lint.rc', "--invalid-consumer-option\n")
    junit_pipeline
    refute @status.success?
    assert_includes read('puppet.xml'), '<error type="ReportError">'
  end

  def junit_pipeline
    script = 'bundle exec puppet-lint --no-config --load "$1/lib/project_lint.rb" ' \
             '--config "$1/config/puppet-lint.rc" --config .puppet-lint.rc --json manifests ' \
             '| bundle exec puppet-lint-junit puppet.xml'
    command('bash', '-o', 'pipefail', '-c', script, 'junit-test', @installed)
  end
end
