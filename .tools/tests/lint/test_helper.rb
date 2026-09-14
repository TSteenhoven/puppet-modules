# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'fixture_support'
require_relative 'finding_values'
require 'open3'
require 'tmpdir'
require 'fileutils'
require_relative '../../lint/lib/config'

# Exercise the installed native linter and copy its implementation into isolated test projects.
module LintTestSupport
  ROOT = File.expand_path('../../..', __dir__)

  def lint_checks(code, rules, fix: false)
    previous = PuppetLint.configuration.fix
    PuppetLint.configuration.fix = fix
    checks = PuppetLint::Checks.new
    checks.instance_variable_set(:@enabled_checks, rules) if rules
    problems = checks.run('example.pp', code)
    [problems, checks.manifest]
  ensure
    PuppetLint.configuration.fix = previous
  end

  def assert_clean_passes(code, rules)
    [false, true].each do |fix|
      problems, unchanged = lint_checks(code, rules, fix: fix)
      assert_empty problems
      assert_equal code, unchanged
    end
  end

  # Integration tests copy the real implementation into an isolated project layout.
  def copy_linter(root)
    FileUtils.mkdir_p(File.join(root, '.tools/lint'))
    FileUtils.cp_r(File.join(ROOT, '.tools/lint/lib'), File.join(root, '.tools/lint'))
    %w[.puppet-lint.rc Gemfile Gemfile.lock].each do |name|
      FileUtils.cp(File.join(ROOT, name), root)
    end
  end
end
