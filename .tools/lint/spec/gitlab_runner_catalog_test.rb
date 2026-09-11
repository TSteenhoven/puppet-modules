require_relative 'test_helper'
require_relative 'support/catalogs'
require 'shellwords'
require 'yaml'

class GitlabRunnerCatalogTest < Minitest::Test
  BASE = "include docker\ninclude basic_settings::systemd\n".freeze

  def resource(catalog, type, title)
    ProjectLint::Catalogs.resource(catalog, type, title)
  end

  def graph_for(catalog)
    graph = ProjectLint::Catalogs.relationship_graph(catalog)
    assert_empty graph.find_cycles_in_graph.map { |cycle| cycle.map(&:ref) }
    graph
  end

  def dependencies(graph, ref)
    graph.dependencies(graph.vertices.find { |vertex| vertex.ref == ref }).map(&:ref)
  end

  def test_registration_waits_for_the_running_compose_service_and_its_files
    catalog = ProjectLint::Catalogs.compile(BASE + <<~'PUPPET')
      docker::gitlab_runner { 'synthetic': auto_register => true, runner_token => Sensitive('glrt-synthetic-bootstrap') }
    PUPPET
    graph = graph_for(catalog)
    requirements = dependencies(graph, 'Exec[docker_gitlab_runner_register_synthetic]')
    %w[/opt/docker/synthetic /opt/docker/synthetic/config /opt/docker/synthetic/.env
       /opt/docker/synthetic/docker-compose.yml /opt/docker/synthetic/runner-token].each do |path|
      assert_includes requirements, "File[#{path}]"
    end
    %w[docker docker-compose-plugin].each { |name| assert_includes requirements, "Package[#{name}]" }
    [
      'Service[docker-compose-synthetic]',
      'File[/etc/systemd/system/core-services.target.d/docker-compose-synthetic_dependency.conf]',
      'File[/etc/systemd/system/docker-compose-synthetic.service]',
    ].each { |ref| assert_includes requirements, ref }
    assert_includes dependencies(graph, 'Service[docker-compose-synthetic]'), 'Exec[docker_compose_systemd_daemon_reload_synthetic]'
    service = resource(catalog, 'Service', 'docker-compose-synthetic')
    assert_equal 'running', service['ensure']
    assert_equal false, service['enable']
    assert_equal ['File[/opt/docker/synthetic/docker-compose.yml]', 'File[/opt/docker/synthetic/.env]'], service['subscribe']
    registration = resource(catalog, 'Exec', 'docker_gitlab_runner_register_synthetic')
    assert_equal 'Docker::Compose[synthetic]', registration['require']
    assert_equal 'File[/opt/docker/synthetic/runner-token]', resource(catalog, 'Docker::Compose_exec', 'docker_gitlab_runner_register_synthetic')['require']
    assert_equal '/opt/docker/synthetic/config/config.toml', registration['creates']
    assert_nil registration['unless']
    assert_nil registration['onlyif']
    assert_equal false, registration['logoutput']
    assert_equal 300, registration['timeout']
    unit = resource(catalog, 'File', '/etc/systemd/system/docker-compose-synthetic.service')['content']
    assert_includes unit, 'TimeoutStopSec=300'
    assert_includes unit, 'UMask=0077'
    refute_includes unit, '--pull'
    refute_includes unit, 'ExecStartPre='
    binding = resource(catalog, 'File', '/etc/systemd/system/core-services.target.d/docker-compose-synthetic_dependency.conf')['content']
    assert_includes binding, 'BindsTo=docker-compose-synthetic.service'
  end

  def test_bootstrap_privacy_runtime_state_and_direct_command
    catalog = ProjectLint::Catalogs.compile(BASE + <<~'PUPPET')
      docker::gitlab_runner { 'synthetic': auto_register => true, runner_token => Sensitive('glrt-synthetic-bootstrap') }
    PUPPET
    token = resource(catalog, 'File', '/opt/docker/synthetic/runner-token')
    assert_equal '0600', token['mode']
    assert_equal 'root', token['owner']
    assert_equal 'root', token['group']
    assert_equal false, token['show_diff']
    assert_equal false, token['backup']
    assert_includes catalog['resources'].find { |r| r['title'] == '/opt/docker/synthetic/runner-token' }['sensitive_parameters'], 'content'
    command = resource(catalog, 'Exec', 'docker_gitlab_runner_register_synthetic')['command']
    words = Shellwords.split(command)
    assert_includes words, 'label=com.docker.compose.project=synthetic'
    assert_includes words, 'label=com.docker.compose.service=runner'
    assert_equal ['/usr/bin/docker', 'exec', '-i', '$container_id', '/bin/sh', '-c'], words[(words.index('exec') - 1), 6]
    assert_includes words, '--non-interactive'
    assert_equal 'alpine:latest', words[words.index('--docker-image') + 1]
    assert_equal 'if-not-present', words[words.index('--docker-pull-policy') + 1]
    assert_includes words[words.index('-c') + 1], 'CI_SERVER_TOKEN=$(cat)'
    refute_includes command, 'glrt-'
    %w[-t -it --registration-token --token --env --privileged].each { |flag| refute_includes words, flag }
    refute_includes command, '/var/run/docker.sock'
    assert_equal ['<', '/opt/docker/synthetic/runner-token'], words.last(2)
    env = resource(catalog, 'File', '/opt/docker/synthetic/.env')['content']
    env = env.unwrap if env.respond_to?(:unwrap)
    assert_equal "# Managed by puppet\nTAG=latest\n", env
    config = resource(catalog, 'File', '/opt/docker/synthetic/config')
    assert_equal '0700', config['mode']
    %w[purge recurse content source].each { |attribute| assert_nil config[attribute] }
    refute catalog['resources'].any? { |r| r['type'] == 'File' && r['title'].match?(%r{/config/(config.toml|\.runner_system_id)$}) }
    refute catalog['resources'].any? { |r| r['type'] == 'File' && r['title'].start_with?('/usr/local/sbin/') }
    refute catalog['resources'].any? { |r| r['type'] == 'Package' && r['title'].include?('python') }
  end

  def test_image_tag_is_a_string_with_only_environment_line_break_protection
    ['alpine-v18.0.0', '-docker-validates-this', 'a:b'].each do |tag|
      catalog = ProjectLint::Catalogs.compile(BASE + "docker::gitlab_runner { 'synthetic': auto_register => true, image_tag => '#{tag}' }")
      env = resource(catalog, 'File', '/opt/docker/synthetic/.env')['content']
      env = env.unwrap if env.respond_to?(:unwrap)
      assert_includes env, "TAG=#{tag}\n"
    end
    ['"latest\\nEXTRA=bad"', '"latest\\rEXTRA=bad"', '42'].each do |invalid|
      assert_raises(Puppet::Error) { ProjectLint::Catalogs.compile(BASE + "docker::gitlab_runner { 'synthetic': image_tag => #{invalid} }") }
    end
  end

  def test_disabled_registration_and_missing_bootstrap_token_remain_supported
    [false, true].each do |auto|
      catalog = ProjectLint::Catalogs.compile(BASE + "docker::gitlab_runner { 'synthetic': auto_register => #{auto} }")
      assert_equal 'absent', resource(catalog, 'File', '/opt/docker/synthetic/runner-token')['ensure']
      assert_equal auto, catalog['resources'].any? { |r| r['type'] == 'Exec' && r['title'] == 'docker_gitlab_runner_register_synthetic' }
      graph_for(catalog)
    end
  end

  def test_registration_input_validation_and_literal_description_transport
    ["runner_url => 'https://synthetic:secret@example.org/'", "runner_url => 'http://gitlab.example.org/'",
     "runner_url => 'https://gitlab.example.org/?token=synthetic'", "runner_description => \"name\\nother\""].each do |invalid|
      assert_raises(Puppet::Error) { ProjectLint::Catalogs.compile(BASE + "docker::gitlab_runner { 'synthetic': auto_register => true, #{invalid} }") }
    end
    %w[../escape . .. Uppercase -leading].each do |name|
      assert_raises(Puppet::Error) { ProjectLint::Catalogs.compile(BASE + "docker::gitlab_runner { '#{name}': }") }
    end
    assert_raises(Puppet::Error) { ProjectLint::Catalogs.compile("docker::gitlab_runner { 'synthetic': }") }
    catalog = ProjectLint::Catalogs.compile(BASE + <<~'PUPPET')
      docker::gitlab_runner { 'synthetic': auto_register => true, runner_description => 'space "quotes" $(false) `false` %n $VALUE' }
    PUPPET
    words = Shellwords.split(resource(catalog, 'Exec', 'docker_gitlab_runner_register_synthetic')['command'])
    assert_equal 'space "quotes" $(false) `false` %n $VALUE', words[words.index('--description') + 1]
  end

  def test_two_stacks_have_separate_storage_and_use_existing_compose_behavior
    %w[present absent].each do |second|
      catalog = ProjectLint::Catalogs.compile(BASE + <<~PUPPET)
        class { 'basic_settings::monitoring': package => 'openitcockpit' }
        docker::gitlab_runner { 'first': auto_register => true }
        docker::gitlab_runner { 'second': ensure => #{second}, auto_register => true }
      PUPPET
      graph_for(catalog)
      first = resource(catalog, 'Basic_settings::Monitoring_custom', 'docker_compose_first')
      assert_includes first['cmd'], '/opt/docker/first'
      if second == 'present'
        other = resource(catalog, 'Basic_settings::Monitoring_custom', 'docker_compose_second')
        assert_includes other['cmd'], '/opt/docker/second'
        refute_equal resource(catalog, 'Exec', 'docker_gitlab_runner_register_first')['creates'], resource(catalog, 'Exec', 'docker_gitlab_runner_register_second')['creates']
      else
        assert_equal 'absent', resource(catalog, 'File', '/opt/docker/second')['ensure']
        refute catalog['resources'].any? { |r| r['type'] == 'Exec' && r['title'].include?('second') }
      end
    end
  end

  def test_original_directory_removal_and_existing_stack_startup
    cleanup = ProjectLint::Catalogs.compile("docker::gitlab_runner { 'synthetic': ensure => absent, auto_register => true }")
    graph_for(cleanup)
    assert_equal 'absent', resource(cleanup, 'File', '/opt/docker/synthetic')['ensure']
    refute cleanup['resources'].any? { |r| r['type'] == 'Exec' }
    catalog = ProjectLint::Catalogs.compile(BASE + <<~'PUPPET')
      docker::compose { 'generic': compose_source => 'puppet:///modules/docker/twenty.yaml' }
      docker::twenty { 'crm': database_password => Sensitive('synthetic'), secret_key => Sensitive('synthetic') }
      docker::authentik { 'identity': database_password => Sensitive('synthetic'), secret_key => Sensitive('synthetic'), akadmin_remove => false }
    PUPPET
    graph_for(catalog)
    %w[generic crm identity].each do |name|
      service = resource(catalog, 'Service', "docker-compose-#{name}")
      assert_equal 'running', service['ensure']
      assert_equal false, service['enable']
    end
  end

  def test_compose_mounts_stop_signal_and_image_contract
    runner = YAML.load_file(File.join(ProjectLint::ROOT, 'docker/files/gitlab_runner.yaml')).fetch('services').fetch('runner')
    assert_equal 'gitlab/gitlab-runner:${TAG:-latest}', runner['image']
    assert_equal false, runner['privileged']
    assert_equal 'SIGQUIT', runner['stop_signal']
    assert_equal '240s', runner['stop_grace_period']
    assert_equal ['./config', '/var/run/docker.sock'], runner['volumes'].map { |volume| volume['source'] }
    assert runner['volumes'].all? { |volume| volume['bind']['create_host_path'] == false }
    %w[ports container_name command entrypoint].each { |key| assert_nil runner[key] }
  end
end
