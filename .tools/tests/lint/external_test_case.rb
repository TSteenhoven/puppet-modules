# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'external_project_setup'
require_relative 'cli_assertions'

# Run the real downstream entry point under isolated project and Bundler environments.
class ExternalTestCase < Minitest::Test
  include LintFixtureSupport
  include LintTestSupport
  include ExternalProjectSetup
  include CliAssertions

  FIXTURE_GROUP = 'external_project_test'

  def write(relative, code)
    path = File.join(@project, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, code)
  end

  def write_shared(relative, code)
    write(File.join(ExternalProjectSetup::TOOLING_PATH, relative), code)
  end

  def append(root, relative, code)
    File.open(File.join(root, relative), 'a') { |file| file.puts code }
  end

  def read(relative)
    File.read(File.join(@project, relative))
  end

  def remove(root, relative)
    FileUtils.rm(File.join(root, relative))
  end

  def replace_script(before, after)
    write('.tools/lint.rb', read('.tools/lint.rb').sub(before, after))
  end

  def run_project(*command, extra_env: {}, directory: @project)
    env = Bundler.unbundled_env.reject { |key, _| key.start_with?('BUNDLE_') }
    env['BUNDLE_USER_HOME'] = File.join(@project, 'personal-bundle')
    env.merge!(extra_env)
    Open3.capture3(env, *command, chdir: directory, unsetenv_others: true)
  end

  def cli(*arguments, **options)
    run_project(RbConfig.ruby, File.join(@project, '.tools/lint.rb'), *arguments, **options)
  end

  def assert_project_success(*arguments, **options)
    @output, @errors, @status = run_project(*arguments, **options)
    assert @status.success?, @output + @errors
  end

  def assert_project_failure(*arguments, **options)
    @output, @errors, @status = run_project(*arguments, **options)
    refute @status.success?, @output + @errors
  end

  def assert_no_cache
    [@project, @tooling].each { |root| refute File.exist?(File.join(root, '.cache')) }
  end
end
