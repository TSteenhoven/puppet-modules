require_relative 'test_helper'
require_relative 'support/catalogs'
require 'digest'
require 'shellwords'

class NginxCatalogTest < Minitest::Test
  def registration(catalog, name = 'synthetic')
    ProjectLint::Catalogs.resource(catalog, 'Basic_settings::Monitoring_custom', "nginx_cert_#{Digest::SHA256.hexdigest(name)}")
  end

  def assert_acyclic(catalog)
    graph = ProjectLint::Catalogs.relationship_graph(catalog)
    assert_empty graph.find_cycles_in_graph.map { |cycle| cycle.map(&:ref) }
    graph
  end

  def test_service_state_and_vhost_notifications_with_and_without_systemd
    [false, true].each do |systemd|
      catalog = ProjectLint::Catalogs.compile(<<~PUPPET)
        #{systemd ? "package { 'systemd': ensure => installed }" : ''}
        include nginx
        nginx::server { 'synthetic': server_name => 'app.example.org', php_fpm_enable => false }
      PUPPET
      refute catalog['resources'].any? { |resource| resource['type'] == 'Class' && resource['title'] == 'Nginx::Service' }
      service = ProjectLint::Catalogs.resource(catalog, 'Service', 'nginx')
      assert_equal !systemd, service['enable']
      systemd ? assert_nil(service['ensure']) : assert_equal(true, service['ensure'])
      graph = assert_acyclic(catalog)
      nginx = graph.vertices.find { |resource| resource.ref == 'Service[nginx]' }
      dependencies = graph.dependencies(nginx).map(&:ref)
      assert_includes dependencies, 'Package[nginx]'
      assert_includes dependencies, 'File[/etc/nginx/conf.d]'
      assert_includes dependencies, 'File[/etc/nginx/conf.d/synthetic.conf]'
      file = ProjectLint::Catalogs.resource(catalog, 'File', '/etc/nginx/conf.d/synthetic.conf')
      assert_equal 'Service[nginx]', file['notify']
      assert_equal '0600', file['mode']
    end
  end

  def test_validation_applies_only_to_active_registrations
    ['openitcockpit', 'none', nil].product(%w[present absent]).each do |backend, state|
      ["validity_critical => 30, validity_warning => 30", "validity_critical => 31, validity_warning => 30",
       'config_file => "/tmp/synthetic\\n.conf"', 'config_file => "/tmp/synthetic\\r.conf"', 'config_file => "/tmp/synthetic\\t.conf"'].each do |invalid|
        attributes = invalid.start_with?('config_file') ? invalid : "config_file => '/tmp/synthetic.conf', #{invalid}"
        code = <<~PUPPET
          #{backend ? "class { 'basic_settings::monitoring': package => '#{backend}' }" : ''}
          include nginx
          nginx::monitoring_cert { 'synthetic': ensure => '#{state}', #{attributes} }
        PUPPET
        if invalid.include?('\\n')
          # Mandatory parameter types still apply during retirement; Unix paths cannot contain newlines.
          error = assert_raises(Puppet::Error) { ProjectLint::Catalogs.compile(code) }
          assert_includes error.message, "parameter 'config_file' expects a Stdlib::Absolutepath"
        elsif backend == 'openitcockpit' && state == 'present'
          error = assert_raises(Puppet::Error) { ProjectLint::Catalogs.compile(code) }
          assert_includes error.message, 'requires ordered positive validity thresholds and a configuration path without control characters'
        else
          # There is deliberately no target File: retiring a registration must not require its former config.
          actual = registration(ProjectLint::Catalogs.compile(code))
          assert_equal 'absent', actual['ensure']
          assert_nil actual['cmd']
          assert_nil actual['require']
        end
      end
    end
  end

  def test_active_and_retired_targets_share_one_executable_and_keep_escaped_arguments
    catalog = ProjectLint::Catalogs.compile(<<~'PUPPET')
      class { 'basic_settings::monitoring': package => 'openitcockpit' }
      include nginx
      file { '/tmp/synthetic check.conf': ensure => file }
      nginx::monitoring_cert { 'synthetic':
        config_file => '/tmp/synthetic check.conf',
        server_name => "app.example.org\talias.example.org",
      }
      nginx::monitoring_cert { 'retired':
        config_file => '/tmp/retired.conf', ensure => absent, validity_critical => 30, validity_warning => 30,
      }
    PUPPET
    active = registration(catalog)
    assert_equal 'present', active['ensure']
    assert_equal ['-n', 'app.example.org alias.example.org', '-f', '/tmp/synthetic check.conf', '-l', '6000', '-t', '30', '-c', '14', '-w', '30'], Shellwords.split(active['cmd'])
    assert_equal 'absent', registration(catalog, 'retired')['ensure']
    assert_equal 'nginx_cert', active['script']
    executable = ProjectLint::Catalogs.resource(catalog, 'File', '/etc/openitcockpit-agent/plugins/check_nginx_cert')
    assert_equal 'root', executable['owner']
    assert_equal '0700', executable['mode']
    assert_acyclic(catalog)
  end

  def test_parent_and_active_configuration_dependencies_remain_required
    error = assert_raises(Puppet::Error) do
      ProjectLint::Catalogs.compile("nginx::monitoring_cert { 'synthetic': config_file => '/tmp/synthetic.conf' }")
    end
    assert_includes error.message, 'nginx class must be included'
    error = assert_raises(Puppet::Error) do
      ProjectLint::Catalogs.compile(<<~'PUPPET')
        class { 'basic_settings::monitoring': package => 'openitcockpit' }
        include nginx
        nginx::monitoring_cert { 'synthetic': config_file => '/tmp/synthetic.conf' }
      PUPPET
    end
    assert_includes error.message, 'File[/tmp/synthetic.conf]'
  end

  def test_documented_nginx_compositions_have_no_dependency_cycles
    %w[examples/web.pp examples/docker.pp examples/monitoring.pp examples/site.pp].each do |path|
      model = ProjectLint::Model.new(File.read(path), path)
      model.nodes.each do |node, _|
        next unless node.is_a?(Puppet::Pops::Model::NodeDefinition)

        code = model.text(node)
        next unless code.include?("class { 'nginx':")

        # Compile this documented node for the synthetic test identity without changing its resource declarations.
        code = code.sub(/\Anode\s+'[^']*'\s*\{/, 'node default {')
        graph = ProjectLint::Catalogs.relationship_graph(ProjectLint::Catalogs.compile(code))
        cycles = graph.find_cycles_in_graph.map { |cycle| cycle.map(&:ref) }
        assert_empty cycles, "#{path}:#{node.line}"
      end
    end
  end
end
