require_relative 'test_helper'
require_relative 'support/catalogs'
require_relative 'support/compose_exec'
require 'fileutils'
require 'json'
require 'shellwords'

class GitlabRunnerBehaviorTest < Minitest::Test
  def with_registration
    Dir.mktmpdir('runner-command-') do |directory|
      root = File.realpath(directory)
      sentinel = "#{root}/unexpected-command"
      description = "literal \"quotes\" $(touch #{sentinel}) `false` $VALUE %n"
      literal = "'" + description.gsub(/[\\']/) { |character| "\\#{character}" } + "'"
      catalog = ProjectLint::Catalogs.compile(<<~PUPPET)
        include docker
        include basic_settings::systemd
        docker::gitlab_runner { 'synthetic':
          auto_register => true,
          runner_description => #{literal},
          runner_url => 'https://gitlab.example.org/',
        }
      PUPPET
      parameters = ProjectLint::Catalogs.resource(catalog, 'Exec', 'docker_gitlab_runner_register_synthetic')
      project = "#{root}/project"
      FileUtils.mkdir_p("#{project}/config")
      File.write("#{project}/runner-token", 'glrt-synthetic-bootstrap')
      docker = "#{root}/docker"
      ProjectLint::ComposeExec.write_docker(docker)
      runner = "#{root}/gitlab-runner"
      File.write(runner, "#!#{RbConfig.ruby}\n" + <<~'RUNNER')
        require 'json'
        token = ENV.fetch('CI_SERVER_TOKEN')
        File.write(ENV.fetch('TEST_RUNNER_RESULT'), JSON.dump('arguments' => ARGV, 'token' => token))
        puts token
        warn token
        exit 1 if ENV['TEST_RUNNER_FAIL'] == 'true'
        File.write(ENV.fetch('TEST_RUNNER_CONFIG'), 'synthetic runtime state')
        File.write(ENV.fetch('TEST_RUNNER_ID'), 'r_synthetic123')
      RUNNER
      [docker, runner].each { |path| File.chmod(0o700, path) }
      command = ProjectLint::ComposeExec.command(parameters, docker).gsub('/opt/docker/synthetic', project)
      creates = parameters.fetch('creates').sub('/opt/docker/synthetic', project)
      environment = {
        'PATH' => "#{root}:#{ENV.fetch('PATH')}",
        'TEST_DOCKER_ARGS' => "#{root}/docker-args.json", 'TEST_RUNNER_RESULT' => "#{root}/runner-result.json",
        'TEST_RUNNER_CONFIG' => creates, 'TEST_RUNNER_ID' => "#{project}/config/.runner_system_id",
        'TEST_RUNNER_FAIL' => 'false',
        'TEST_DOCKER_CONTAINERS' => 'aabbccddeeff',
        'TEST_DOCKER_PS_STATUS' => '0',
      }
      # The real Puppet guard is evaluated without applying a catalog or contacting Docker.
      guard = Puppet::Type.type(:exec).new(name: 'synthetic-registration', command: command, creates: creates, provider: :shell, noop: true)
      run = -> { Open3.capture3(environment, '/bin/sh', '-c', command) }
      yield root, project, description, environment, guard, run
    end
  end

  def test_rendered_command_preserves_arguments_and_reads_token_only_inside_the_container
    with_registration do |root, _project, description, environment, guard, run|
      assert guard.check_all_attributes
      refute File.exist?(environment['TEST_DOCKER_ARGS'])
      output, errors, status = run.call
      assert status.success?, errors
      assert_empty output
      assert_empty errors
      result = JSON.parse(File.read(environment['TEST_RUNNER_RESULT']))
      assert_equal 'glrt-synthetic-bootstrap', result['token']
      assert_equal [
        'register', '--non-interactive', '--url', 'https://gitlab.example.org/', '--executor', 'docker',
        '--docker-image', 'alpine:latest', '--docker-pull-policy', 'if-not-present', '--description', description,
      ], result['arguments']
      refute_includes File.read(environment['TEST_DOCKER_ARGS']), 'glrt-'
      refute File.exist?("#{root}/unexpected-command")
      refute guard.check_all_attributes
    end
  end

  def test_existing_config_guard_is_read_only_and_independent_of_bootstrap_token
    with_registration do |_root, project, _description, environment, guard, run|
      _, errors, status = run.call
      assert status.success?, errors
      File.unlink("#{project}/runner-token")
      original_id = File.read(environment['TEST_RUNNER_ID'])
      ['', 'synthetic rotated runtime token'].each do |state|
        File.write(environment['TEST_RUNNER_CONFIG'], state)
        before = File.stat(environment['TEST_RUNNER_CONFIG']).mtime
        refute guard.check_all_attributes
        assert_equal state, File.read(environment['TEST_RUNNER_CONFIG'])
        assert_equal before, File.stat(environment['TEST_RUNNER_CONFIG']).mtime
        assert_equal original_id, File.read(environment['TEST_RUNNER_ID'])
      end
      assert_equal 0o600, File.stat(environment['TEST_RUNNER_ID']).mode & 0o777
    end
  end

  def test_registration_failure_is_propagated_without_secret_output
    with_registration do |_root, _project, _description, environment, guard, run|
      environment['TEST_RUNNER_FAIL'] = 'true'
      output, errors, status = run.call
      refute status.success?
      assert_empty output
      assert_empty errors
      assert guard.check_all_attributes
      refute File.exist?(environment['TEST_RUNNER_CONFIG'])
    end
  end

  def test_missing_bootstrap_file_prevents_the_exec_from_registering
    with_registration do |_root, project, _description, environment, guard, run|
      File.unlink("#{project}/runner-token")
      output, errors, status = run.call
      refute status.success?
      assert_empty output
      refute_includes errors, 'glrt-'
      refute File.exist?(environment['TEST_DOCKER_ARGS'])
      refute File.exist?(environment['TEST_RUNNER_RESULT'])
      assert guard.check_all_attributes
    end
  end

  def test_missing_running_container_prevents_registration
    with_registration do |_root, _project, _description, environment, guard, run|
      environment['TEST_DOCKER_CONTAINERS'] = ''
      output, errors, status = run.call
      refute status.success?
      assert_empty output
      assert_includes errors, 'Expected exactly one running Compose service container'
      refute File.exist?(environment['TEST_DOCKER_ARGS'])
      refute File.exist?(environment['TEST_RUNNER_RESULT'])
      assert guard.check_all_attributes
    end
  end
end
