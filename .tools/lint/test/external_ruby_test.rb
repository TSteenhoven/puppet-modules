# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'

# Exercise both linters from a single packaged dependency.
class ExternalRubyTest < Minitest::Test
  include InstalledGemSupport

  def test_rubocop_and_its_profile_are_supplied_by_the_installed_gem
    write('.rubocop.yml', <<~YAML)
      inherit_gem:
        lint-project: config/rubocop.yml
    YAML
    write('example.rb', "# frozen_string_literal: true\n\nvalue = 1\nputs value\n")
    run_success('bundle', 'exec', 'rubocop', '--config', '.rubocop.yml', '--cache', 'false', 'example.rb')
    write('example.rb', "# frozen_string_literal: true\n\nvalue=1\nputs value\n")
    command('bundle', 'exec', 'rubocop', '--config', '.rubocop.yml', '--cache', 'false', 'example.rb')
    refute @status.success?
    assert_includes @output, 'Layout/SpaceAroundOperators'
  end

  def test_puppet_lint_loads_without_development_dependencies_or_loading_rubocop
    script = "abort 'development dependency leaked' unless " \
             '(Bundler.load.specs.map(&:name) & %w[metadata-json-lint rake minitest]).empty?; ' \
             "require 'project_lint'; abort 'RuboCop loaded by Puppet-lint' if defined?(RuboCop)"
    run_success('bundle', 'exec', 'ruby', '-e', script)
    lint('manifests')
    assert @status.success?, @output + @errors
  end
end
