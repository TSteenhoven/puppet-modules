# frozen_string_literal: true

require_relative 'test_helper'
require 'yaml'

# Validate the independent job and artifact contracts in both documented CI configurations.
class GuideCiTest < Minitest::Test
  include LintTestSupport

  def guide
    File.read(File.join(LintTestSupport::ROOT, '.tools/lint/README.md'))
  end

  def test_ci_examples_keep_independent_checks_and_failure_artifacts
    github = configuration_with('jobs')
    gitlab = configuration_with('.check_setup')
    assert_equal 'bash', github.dig('defaults', 'run', 'shell')
    assert_includes gitlab.dig('.check_setup', 'before_script'), 'set -eo pipefail'
    %w[puppet_validate puppet_lint ruby_lint tool_tests].each do |name|
      assert_github_job(github.fetch('jobs').fetch(name))
      assert_gitlab_job(gitlab.fetch(name))
    end
  end

  def configuration_with(key)
    configurations = guide.scan(/^```yaml\n(.*?)^```/m).flatten.map { |text| YAML.safe_load(text) }
    config = configurations.find { |item| item.is_a?(Hash) && item.key?(key) }
    refute_nil config
    config
  end

  def test_ci_jobs_invoke_the_documented_checks_and_report_conversion
    github = configuration_with('jobs').fetch('jobs')
    gitlab = configuration_with('.check_setup')
    { 'puppet_validate' => /bundle exec (?:puppet-validate-junit|rake validate:puppet)/,
      'puppet_lint' => /bundle exec puppet-lint-junit/,
      'ruby_lint' => /bundle exec rubocop --config .rubocop.yml/,
      'tool_tests' => /bundle exec rake test/ }.each do |job, command|
      runs = github.fetch(job).fetch('steps').filter_map { |step| step['run'] }.join("\n")
      assert_match command, runs
      assert_match command, gitlab.fetch(job).fetch('script').join("\n")
    end
  end

  def assert_github_job(job)
    refute job.key?('needs')
    steps = job.fetch('steps')
    assert(steps.any? { |step| step['run'] == 'git diff --exit-code HEAD --' })
    refute(steps.any? { |step| step.fetch('run', '').include?('--fix') })
    uploads = steps.select { |step| step.fetch('uses', '').start_with?('actions/upload-artifact@') }
    assert_github_uploads(uploads)
  end

  def assert_github_uploads(uploads)
    assert_equal 1, uploads.size
    upload = uploads.first
    assert_equal '${{ !cancelled() }}', upload.fetch('if')
    assert upload.dig('with', 'include-hidden-files')
    assert_match(%r{\A\$\{\{ env.PROJECT_REPORT_DIR \}\}/(?:[\w-]+|TEST-\*)\.xml\z},
                 upload.dig('with', 'path'))
  end

  def assert_gitlab_job(job)
    refute job.key?('needs')
    assert_equal '.check_setup', job.fetch('extends')
    assert_equal 'git diff --exit-code HEAD --', job.fetch('script').last
    refute(job.fetch('script').any? { |command| command.include?('--fix') })
    assert_equal 'always', job.dig('artifacts', 'when')
    assert_equal [job.dig('artifacts', 'reports', 'junit')], job.dig('artifacts', 'paths')
  end
end
