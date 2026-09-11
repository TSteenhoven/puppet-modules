require_relative 'test_helper'
require_relative 'support/catalogs'
require_relative 'support/compose_exec'
require 'json'

class ComposeExecTest < Minitest::Test
  BASE = <<~'PUPPET'.freeze
    include docker
    include basic_settings::systemd
    docker::compose { 'synthetic': compose_source => 'puppet:///modules/docker/gitlab_runner.yaml' }
  PUPPET

  def literal(value)
    "'" + value.gsub(/[\\']/) { |character| "\\#{character}" } + "'"
  end

  def resource(catalog, type, title)
    ProjectLint::Catalogs.resource(catalog, type, title)
  end

  def with_docker
    Dir.mktmpdir('compose-exec-') do |directory|
      root = File.realpath(directory)
      docker = "#{root}/docker"
      ProjectLint::ComposeExec.write_docker(docker)
      environment = {
        'TEST_DOCKER_CALLS' => "#{root}/calls.jsonl", 'TEST_DOCKER_ARGS' => "#{root}/exec.json",
        'TEST_DOCKER_CONTAINERS' => 'aabbccddeeff', 'TEST_DOCKER_PS_STATUS' => '0',
      }
      yield root, docker, environment
    end
  end

  def test_argument_and_environment_boundaries_survive_the_host_shell
    with_docker do |root, docker, environment|
      value = "spaces 'quotes' \"double\" $(touch #{root}/unexpected) `false` $VALUE\nsecond line"
      # The stand-in runs the actual escaped argv, writing a local JSON result instead of using a container.
      code = "require 'json'; File.write(ARGV.shift, JSON.dump([ARGV, ENV.fetch('SYNTHETIC_VALUE')]))"
      command = [RbConfig.ruby, '-e', code, "#{root}/result.json", value, '']
      catalog = ProjectLint::Catalogs.compile(BASE + <<~PUPPET)
        docker::compose_exec { 'transport':
          command => [#{command.map { |word| literal(word) }.join(', ')}],
          compose_name => 'synthetic', service => 'runner',
          environment => { 'SYNTHETIC_VALUE' => Sensitive(#{literal(value)}) },
        }
      PUPPET
      parameters = resource(catalog, 'Exec', 'transport')
      _, errors, status = Open3.capture3(environment, '/bin/sh', '-c', ProjectLint::ComposeExec.command(parameters, docker))
      assert status.success?, errors
      assert_equal [[value, ''], value], JSON.parse(File.read("#{root}/result.json"))
      refute File.exist?("#{root}/unexpected")
      entry = catalog['resources'].find { |r| r['type'] == 'Exec' && r['title'] == 'transport' }
      assert_includes entry['sensitive_parameters'], 'command'
      assert_equal false, parameters['logoutput']
      refute_includes JSON.parse(File.read(environment['TEST_DOCKER_ARGS'])), '-t'
    end
  end

  def test_guard_controls_execution_and_noop_does_not_mutate_the_application
    with_docker do |root, docker, environment|
      marker = "#{root}/initialized"
      catalog = ProjectLint::Catalogs.compile(BASE + <<~PUPPET)
        docker::compose_exec { 'initialize':
          command => ['/usr/bin/touch', #{literal(marker)}],
          compose_name => 'synthetic', service => 'runner',
          unless => ['/bin/sh', '-c', 'test -e "$1"', 'check', #{literal(marker)}],
          stdin_file => #{literal("#{root}/bootstrap")},
        }
      PUPPET
      parameters = resource(catalog, 'Exec', 'initialize')
      command = ProjectLint::ComposeExec.command(parameters, docker)
      guard = Puppet::Type.type(:exec).new(
        name: 'synthetic-init', command: command, provider: :shell, noop: true,
        unless: ProjectLint::ComposeExec.command(parameters, docker, 'unless'),
        environment: environment.map { |key, value| "#{key}=#{value}" },
      )
      assert guard.check_all_attributes
      refute File.exist?(marker)
      File.write("#{root}/bootstrap", 'synthetic stdin')
      _, errors, status = Open3.capture3(environment, '/bin/sh', '-c', command)
      assert status.success?, errors
      File.unlink("#{root}/bootstrap")
      refute guard.check_all_attributes
      assert File.exist?(marker)
      entry = catalog['resources'].find { |r| r['type'] == 'Exec' && r['title'] == 'initialize' }
      assert_includes entry['sensitive_parameters'], 'unless'
    end
  end

  def test_missing_ambiguous_and_failed_discovery_never_executes
    catalog = ProjectLint::Catalogs.compile(BASE + <<~'PUPPET')
      docker::compose_exec { 'discovery': command => ['/usr/bin/true'], compose_name => 'synthetic', service => 'runner' }
    PUPPET
    parameters = resource(catalog, 'Exec', 'discovery')
    with_docker do |_root, docker, environment|
      [['', '0'], ["aabbccddeeff\n112233445566", '0'], ['aabbccddeeff', '1']].each do |containers, code|
        environment['TEST_DOCKER_CONTAINERS'] = containers
        environment['TEST_DOCKER_PS_STATUS'] = code
        _, _, status = Open3.capture3(environment, '/bin/sh', '-c', ProjectLint::ComposeExec.command(parameters, docker))
        refute status.success?
        refute File.exist?(environment['TEST_DOCKER_ARGS'])
      end
    end
  end

  def test_application_failure_is_returned_to_puppet
    catalog = ProjectLint::Catalogs.compile(BASE + <<~'PUPPET')
      docker::compose_exec { 'failure': command => ['/bin/sh', '-c', 'exit 42'], compose_name => 'synthetic', service => 'runner' }
    PUPPET
    with_docker do |_root, docker, environment|
      _, _, status = Open3.capture3(environment, '/bin/sh', '-c', ProjectLint::ComposeExec.command(resource(catalog, 'Exec', 'failure'), docker))
      assert_equal 42, status.exitstatus
    end
  end

  def test_multiple_callers_keep_their_project_service_and_dependencies
    catalog = ProjectLint::Catalogs.compile(BASE + <<~'PUPPET')
      docker::compose { 'second': compose_source => 'puppet:///modules/docker/gitlab_runner.yaml' }
      docker::compose_exec { 'first-operation': command => ['/usr/bin/true'], compose_name => 'synthetic', service => 'runner' }
      docker::compose_exec { 'second-operation': command => ['/usr/bin/true'], compose_name => 'second', service => 'server' }
    PUPPET
    graph = ProjectLint::Catalogs.relationship_graph(catalog)
    assert_empty graph.find_cycles_in_graph
    with_docker do |_root, docker, environment|
      [['first-operation', 'synthetic', 'runner'], ['second-operation', 'second', 'server']].each do |title, project, service|
        parameters = resource(catalog, 'Exec', title)
        _, errors, status = Open3.capture3(environment, '/bin/sh', '-c', ProjectLint::ComposeExec.command(parameters, docker))
        assert status.success?, errors
        calls = File.readlines(environment['TEST_DOCKER_CALLS']).map { |line| JSON.parse(line) }
        discovery = calls.reverse.find { |arguments| arguments.first == 'ps' }
        assert_includes discovery, "label=com.docker.compose.project=#{project}"
        assert_includes discovery, "label=com.docker.compose.service=#{service}"
        dependencies = graph.dependencies(graph.vertices.find { |v| v.ref == "Exec[#{title}]" }).map(&:ref)
        assert_includes dependencies, "Service[docker-compose-#{project}]"
      end
    end
  end

  def test_public_inputs_reject_invalid_identifiers_and_environment_keys
    ["compose_name => 'bad name', service => 'runner'", "compose_name => 'synthetic', service => 'bad;service'",
     "compose_name => 'synthetic', service => 'runner', environment => { 'bad=key' => 'value' }",
     "compose_name => 'synthetic', service => 'runner', stdin_file => 'relative/path'"].each do |attributes|
      assert_raises(Puppet::Error) do
        ProjectLint::Catalogs.compile(BASE + "docker::compose_exec { 'invalid': command => ['/bin/true'], #{attributes} }")
      end
    end
  end

  def test_authentik_uses_shared_transport_for_updates_and_passwordless_removal
    with_docker do |root, docker, environment|
      # ak's Django shell receives the complete Python argument and environment; no Authentik server is contacted.
      ak = "#{root}/ak"
      File.write(ak, "#!#{RbConfig.ruby}\n" + <<~'RUBY')
        require 'json'
        abort 'unexpected ak command' unless ARGV.first(2) == ['shell', '-c'] && ARGV.length == 3
        values = ENV.select { |key, _| key.start_with?('AK_ADMIN_') }
        File.write(ENV.fetch('TEST_AK_RESULT'), JSON.dump('python' => ARGV.last, 'environment' => values))
      RUBY
      File.chmod(0o700, ak)
      environment['PATH'] = "#{root}:#{ENV.fetch('PATH')}"
      environment['TEST_AK_RESULT'] = "#{root}/ak-result.json"
      password = "synthetic \"quotes\" 'single' $(false) `false` $VALUE"
      %w[present absent].each do |state|
        attributes = state == 'present' ? ", email => 'admin@example.org', password => Sensitive(#{literal(password)})" : ''
        catalog = ProjectLint::Catalogs.compile(BASE + "docker::authentik_admin { 'admin': compose_name => 'synthetic', ensure => #{state}#{attributes} }")
        title = "docker_authentik_admin_#{state}_synthetic_admin"
        resource(catalog, 'Docker::Compose_exec', title)
        parameters = resource(catalog, 'Exec', title)
        %w[command unless].each do |key|
          _, errors, status = Open3.capture3(environment, '/bin/sh', '-c', ProjectLint::ComposeExec.command(parameters, docker, key))
          assert status.success?, errors
          result = JSON.parse(File.read(environment['TEST_AK_RESULT']))
          assert_equal 'admin', result['environment']['AK_ADMIN_USERNAME']
          if state == 'present'
            assert_equal password, result['environment']['AK_ADMIN_PASSWORD']
            assert_includes result['python'], key == 'command' ? 'user.set_password(password)' : 'user.check_password(password)'
          else
            assert_equal ['AK_ADMIN_USERNAME'], result['environment'].keys
            assert_includes result['python'], key == 'command' ? '.delete()' : '.exists()'
          end
          entry = catalog['resources'].find { |r| r['type'] == 'Exec' && r['title'] == title }
          assert_includes entry['sensitive_parameters'], key
        end
      end
    end
  end

  def test_authentik_wrapper_and_forward_declarations_have_no_dependency_cycles
    catalog = ProjectLint::Catalogs.compile(<<~'PUPPET')
      include docker
      include basic_settings::systemd
      docker::authentik_admin { 'extra.admin': compose_name => 'identity', ensure => absent }
      docker::authentik { 'identity': database_password => Sensitive('synthetic'), secret_key => Sensitive('synthetic') }
    PUPPET
    graph = ProjectLint::Catalogs.relationship_graph(catalog)
    assert_empty graph.find_cycles_in_graph
    %w[akadmin extra.admin].each do |username|
      resource(catalog, 'Exec', "docker_authentik_admin_absent_identity_#{username}")
    end
  end
end
