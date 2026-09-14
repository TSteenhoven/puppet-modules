# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'

# Exercise the optional Ruby profile from the packaged dependency.
class ExternalRubyTest < Minitest::Test
  include InstalledGemSupport

  def test_optional_rubocop_profile_works_from_the_installed_gem
    write('.rubocop.yml', <<~YAML)
      inherit_gem:
        puppet-lint-project: config/rubocop.yml
    YAML
    write('example.rb', "# frozen_string_literal: true\n\nvalue = 1\nputs value\n")
    run_success('bundle', 'exec', 'rubocop', '--config', '.rubocop.yml', '--cache', 'false', 'example.rb')
    write('example.rb', "# frozen_string_literal: true\n\nvalue=1\nputs value\n")
    command('bundle', 'exec', 'rubocop', '--config', '.rubocop.yml', '--cache', 'false', 'example.rb')
    refute @status.success?
    assert_includes @output, 'Layout/SpaceAroundOperators'
  end

  def test_puppet_lint_does_not_require_ruby_or_test_development_dependencies
    @env.delete('BUNDLE_FROZEN')
    write('Gemfile', "source 'https://rubygems.org'\ngem 'puppet-lint-project', '= 0.1.0', require: false\n")
    run_success('bundle', 'install', '--local')
    script = "abort 'development dependency leaked' unless " \
             '(Bundler.load.specs.map(&:name) & %w[rubocop rake minitest]).empty?; ' \
             "require 'project_lint'"
    run_success('bundle', 'exec', 'ruby', '-e', script)
    lint('manifests')
    assert @status.success?, @output + @errors
  end
end
