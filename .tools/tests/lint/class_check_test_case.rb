# frozen_string_literal: true

require_relative 'test_helper'

# Shared setup and assertions for related lint contracts.
class ClassCheckTestCase < Minitest::Test
  include FindingValues
  include LintFixtureSupport

  FIXTURE_GROUP = 'class_checks_test'

  CHECK = "defined(Class['basic_settings::monitoring'])"

  def findings(code, path: 'example.pp')
    lint = PuppetLint.new
    lint.path = path
    lint.code = code
    lint.run
    refute lint.problems.any? { |problem|
      problem[:check] == :syntax
    }, 'Class-check fixtures must parse before their findings are asserted'
    lint.problems.select { |problem| problem[:check] == :project_class_check_reuse }
  end

  def with_module_files(paths)
    consumers = ProjectLint::ClassCheckConsumers
    original = consumers.method(:module_files)
    consumers.define_singleton_method(:module_files) { |_| paths }
    yield
  ensure
    consumers.define_singleton_method(:module_files, original)
  end
end
