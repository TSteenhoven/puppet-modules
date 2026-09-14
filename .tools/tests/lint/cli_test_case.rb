# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'cli_files'
require_relative 'cli_assertions'

# Exercise the native CLI using the real project configuration and isolated source files.
class CliTestCase < Minitest::Test
  include LintTestSupport
  include LintFixtureSupport
  include CliFiles
  include CliAssertions

  FIXTURE_GROUP = 'cli_test'

  def cli(*arguments, directory: LintTestSupport::ROOT, env: {}, project_config: true)
    options = project_config ? ['--no-config', '--config', '.puppet-lint.rc'] : []
    Open3.capture3(env, Gem.bin_path('puppet-lint', 'puppet-lint'), *options, *arguments, chdir: directory)
  end
end
