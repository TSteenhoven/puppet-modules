# frozen_string_literal: true

require_relative 'test_helper'

# Exercise the public library entrypoint and native failure boundary in fresh Ruby processes.
class LoadingTest < Minitest::Test
  include LintTestSupport

  BROKEN_CHECK = <<~RUBY
    require 'project_lint'
    PuppetLint.new_check(:synthetic_failure) do
      include ProjectLint::AstCheck
      def check
        raise 'synthetic programming failure'
      end
    end
    lint = PuppetLint.new
    lint.path = 'example.pp'
    lint.code = '$value = 1'
    lint.run
  RUBY

  def test_entrypoint_can_be_required_in_either_order_and_loaded_repeatedly
    ["require 'project_lint'; require 'puppet-lint'",
     "require 'puppet-lint'; require 'project_lint'"].each do |requires|
      script = "#{requires}; 2.times { load Gem.loaded_specs.fetch('lint-project').full_gem_path + " \
               "'/lib/project_lint.rb' }; puts PuppetLint.configuration.checks.grep(/^project_/).size"
      output, errors, status = Open3.capture3(RbConfig.ruby, '-e', script)
      assert status.success?, errors
      assert_empty errors
      assert_equal "22\n", output
    end
  end

  def test_programming_errors_propagate_instead_of_becoming_clean_results
    output, errors, status = Open3.capture3(RbConfig.ruby, '-e', BROKEN_CHECK)
    refute status.success?
    assert_includes output + errors, 'synthetic programming failure'
  end

  def test_invalid_input_does_not_poison_the_next_analysis
    problems, unchanged = lint_checks('class broken (String $value = ) {}', [:project_arrays], fix: true)
    assert_equal([:syntax], problems.map { |problem| problem[:check] })
    assert_equal 'class broken (String $value = ) {}', unchanged
    assert_clean_passes('$values = concat([1], [2])', [:project_arrays])
    assert_equal [:warning], finding_kinds('$values = [1] + [2]', :project_arrays)
  end
end
