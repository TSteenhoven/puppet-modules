# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/reporters'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'project_lint'

# Use native configuration and diagnostics for both isolated checks and interacting fixes.
module LintTestSupport
  ROOT = File.expand_path('../../..', __dir__)
  PuppetLint::OptParser.build(['--no-config', '--config', File.join(ROOT, '.puppet-lint.rc')])

  def fixture_set(pattern)
    paths = Dir[File.join(__dir__, 'fixtures', "#{pattern}.pp")].sort
    refute_empty paths
    paths.map { |path| File.read(path) }
  end

  def fixture(name)
    File.read(File.join(__dir__, 'fixtures', "#{name}.pp"))
  end

  def lint_checks(code, rules = nil, fix: false, path: 'example.pp')
    with_configuration(rules, fix) do
      lint = PuppetLint.new
      lint.path = path
      lint.code = code
      lint.run
      [lint.problems, fix ? lint.manifest : code]
    end
  end

  def with_configuration(rules, fix)
    configuration = PuppetLint.configuration
    enabled = configuration.checks.to_h { |rule| [rule, configuration.public_send("#{rule}_enabled?")] }
    previous_fix = configuration.fix
    apply_checks(configuration.checks.to_h { |rule| [rule, rules.map(&:to_sym).include?(rule)] }) if rules
    configuration.fix = fix
    yield
  ensure
    apply_checks(enabled)
    configuration.fix = previous_fix
  end

  def apply_checks(enabled)
    enabled.each { |rule, active| PuppetLint.configuration.public_send("#{active ? 'enable' : 'disable'}_#{rule}") }
  end

  def findings(code, rule = self.class::RULE, path: 'example.pp')
    problems, = lint_checks(code, [rule], path: path)
    refute problems.any? { |problem| problem[:check] == :syntax }, problems.inspect
    problems
  end

  def finding_kinds(code, *rules)
    findings(code, *rules).map { |problem| problem[:kind] }
  end

  def finding_lines(code, *rules)
    findings(code, *rules).map { |problem| problem[:line] }
  end

  def lint(code, fix: false, rule: self.class::RULE)
    lint_checks(code, [rule], fix: fix)
  end

  def assert_clean_passes(code, rules = [self.class::RULE])
    [false, true].each do |fix|
      problems, unchanged = lint_checks(code, rules, fix: fix)
      assert_empty problems
      assert_equal code, unchanged
    end
  end

  def assert_fix(before, after, *rules, count: nil)
    rules = self.class.const_defined?(:RULE) ? [self.class::RULE] : nil if rules.empty?
    assert_detected(before, rules)
    problems, fixed = lint_checks(before, rules, fix: true)
    assert_fixed(problems, count)
    assert_equal after, fixed
    # Parser validation checks the fix output contract, not module behavior.
    Puppet::Pops::Parser::EvaluatingParser.new.parse_string(fixed, 'example.pp')
    assert_clean_passes(fixed, rules)
    fixed
  end

  def assert_detected(code, rules)
    problems, unchanged = lint_checks(code, rules)
    refute_empty problems
    assert_equal code, unchanged
  end

  def assert_fixed(problems, count)
    assert problems.any? { |problem| problem[:kind] == :fixed }, problems.inspect
    assert_equal(Array.new(count, :fixed), problems.map { |problem| problem[:kind] }) if count
  end

  def assert_preserved(code, kinds, review: false, fix: true)
    problems, fixed = lint(code, fix: fix)
    assert_equal(kinds, problems.map { |problem| problem[:kind] })
    assert_includes problems.first[:message], '[review]' if review
    assert_equal code, fixed
  end

  # Shared Puppet Strings envelope for documentation scenarios.
  module DocumentationInputs
    PROSE = 'This class manages console packages and keyboard configuration, preserves explicit settings, ' \
            'and uses the host defaults when no override is supplied.'

    def document(body, declaration = 'class example {}')
      "# @summary Manages the example.\n#\n#{body}#\n# @api public\n#{declaration}\n"
    end
  end
end

require_relative 'cli_support'

Minitest::Reporters.use!([
                           Minitest::Reporters::DefaultReporter.new,
                           Minitest::Reporters::JUnitReporter.new(File.expand_path('../results', __dir__))
                         ])
