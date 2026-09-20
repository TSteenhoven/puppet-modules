# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'installed_gem_support'

# Exercise path and Git gemspec selection with independently resolved consumer lockfiles.
class ExternalImportsTest < Minitest::Test
  include InstalledGemSupport

  def test_path_consumer_has_its_own_bundle_and_loads_the_monorepo_gemspec
    destination = File.join(@project, 'global-modules/.tools/lint')
    FileUtils.mkdir_p(File.dirname(destination))
    FileUtils.cp_r(File.join(LintTestSupport::ROOT, '.tools/lint'), destination)
    replace_consumer_dependency("gem 'lint-project', path: 'global-modules/.tools/lint', require: false")
    assert_equal File.realpath(destination), @installed
    assert_consumer_outcomes
  end

  def test_git_consumer_selects_the_nested_gemspec_at_an_existing_revision
    repository = File.join(@project, 'source.git')
    run_success('git', 'clone', '--quiet', '--bare', '--no-hardlinks', LintTestSupport::ROOT, repository)
    run_success('git', '--git-dir', repository, 'rev-parse', 'HEAD')
    revision = @output.strip
    dependency = "gem 'lint-project', git: #{repository.dump}, ref: #{revision.dump}, " \
                 "glob: '.tools/lint/*.gemspec', require: false"
    replace_consumer_dependency(dependency)
    assert_includes read('Gemfile.lock'), revision
    refute @installed.start_with?(LintTestSupport::ROOT)
    assert_consumer_outcomes
  end

  def replace_consumer_dependency(dependency)
    @env.delete('BUNDLE_FROZEN')
    @env.delete('RUBYOPT')
    @env.delete('RUBYLIB')
    # Offline gem caches do not provide registry checksums for a new lockfile.
    @env['BUNDLE_LOCKFILE_CHECKSUMS'] = 'false'
    FileUtils.rm_f(File.join(@project, 'Gemfile.lock'))
    write('Gemfile', "source 'https://rubygems.org'\n#{dependency}\n")
    run_success('bundle', 'install', '--local')
    run_success('bundle', 'info', '--path', 'lint-project')
    @installed = @output.strip
    @env['BUNDLE_FROZEN'] = 'true'
  end

  def assert_consumer_outcomes
    lint('manifests')
    assert_equal 0, @status.exitstatus, @output + @errors
    write('manifests/site.pp', "$values = [1] + [2]\n")
    lint('manifests')
    assert_equal 1, @status.exitstatus, @output + @errors
    assert_includes @output, 'project_arrays: warning:'
  end
end
