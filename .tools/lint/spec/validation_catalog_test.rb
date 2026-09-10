require_relative 'test_helper'
require_relative 'support/catalogs'

class ValidationCatalogTest < Minitest::Test
  COMPOSE = <<~'PUPPET'.freeze
    include basic_settings
    include docker
    docker::compose { 'synthetic': compose_source => 'puppet:///modules/profile/compose.yml' }
  PUPPET

  RABBITMQ = <<~'PUPPET'.freeze
    include basic_settings
    include rabbitmq
    class { 'rabbitmq::management': admin_password => 'replace-with-password' }
  PUPPET

  def test_compose_environment_source_validation_preserves_the_removal_path
    error = assert_raises(Puppet::Error) do
      ProjectLint::Catalogs.compile("include basic_settings\ninclude docker\ndocker::compose { 'synthetic': compose_source => 'puppet:///modules/profile/compose.yml', env_source => 'http://example.org/env' }")
    end
    assert_includes error.message, 'docker::compose env_source must start with'
    catalog = ProjectLint::Catalogs.compile("docker::compose { 'synthetic': ensure => absent, env_source => 'http://example.org/env' }")
    assert_equal 'absent', ProjectLint::Catalogs.resource(catalog, 'File', '/opt/docker/synthetic')['ensure']
  end

  def test_authentik_administration_validates_present_passwords_and_allows_passwordless_removal
    ['Sensitive(\'\')', 'Sensitive("synthetic\\npassword")', 'Sensitive("synthetic\\rpassword")'].each do |password|
      error = assert_raises(Puppet::Error) do
        ProjectLint::Catalogs.compile(COMPOSE + "docker::authentik_admin { 'synthetic': compose_name => 'synthetic', email => 'admin@example.org', password => #{password} }")
      end
      assert_includes error.message, 'password must not be empty or contain newlines'
    end

    %w[present absent].each do |state|
      attributes = state == 'present' ? ", email => 'admin@example.org', password => Sensitive('replace-with-password')" : ''
      catalog = ProjectLint::Catalogs.compile(COMPOSE + "docker::authentik_admin { 'synthetic': compose_name => 'synthetic', ensure => #{state}#{attributes} }")
      resource = ProjectLint::Catalogs.resource(catalog, 'Exec', "docker_authentik_admin_#{state}_synthetic_synthetic")
      assert_equal false, resource['logoutput']
      assert_equal 'shell', resource['provider']
      assert_equal 'Docker::Compose[synthetic]', resource['require']
      assert resource['command']
      assert resource['unless']
      service = ProjectLint::Catalogs.resource(catalog, 'Basic_settings::Systemd_service', 'docker-compose-synthetic')
      assert_equal ['File[/opt/docker/synthetic/docker-compose.yml]'], service['service_subscribe']
    end
  end

  def test_rabbitmq_user_validation_preserves_supplied_generated_and_removed_users
    error = assert_raises(Puppet::Error) do
      ProjectLint::Catalogs.compile(RABBITMQ + "rabbitmq::management_user { 'synthetic': }")
    end
    assert_includes error.message, 'User synthetic not present'

    supplied = ProjectLint::Catalogs.compile(RABBITMQ + "rabbitmq::management_user { 'synthetic': password => 'replace-with-password' }")
    assert ProjectLint::Catalogs.resource(supplied, 'Exec', 'rabbitmq_management_user_synthetic')['command']
    assert ProjectLint::Catalogs.resource(supplied, 'Exec', 'rabbitmq_management_user_synthetic_tags')['command']

    generated = ProjectLint::Catalogs.compile(RABBITMQ + <<~'PUPPET')
      basic_settings::login_user { 'synthetic': uid => 2000, gid => 2000, home => '/home/synthetic', password => Sensitive('!!') }
      rabbitmq::management_user { 'synthetic': }
    PUPPET
    resource = ProjectLint::Catalogs.resource(generated, 'Exec', 'rabbitmq_management_user_synthetic')
    assert_includes resource['command'], '/usr/bin/pwgen'
    assert_includes resource['require'], 'Package[pwgen]'

    removed = ProjectLint::Catalogs.compile(RABBITMQ + "rabbitmq::management_user { 'synthetic': ensure => absent }")
    assert_includes ProjectLint::Catalogs.resource(removed, 'Exec', 'rabbitmq_management_user_synthetic')['command'], 'delete_user'
    refute removed['resources'].any? { |resource| resource['title'] == 'rabbitmq_management_user_synthetic_tags' }
  end

  def test_container_wrapper_parent_errors_keep_their_priority
    %w[authentik twenty].each do |wrapper|
      declaration = "docker::#{wrapper} { 'synthetic': database_password => Sensitive('replace-with-password'), secret_key => Sensitive('replace-with-secret'), server_name => 'app.example.org' }"
      error = assert_raises(Puppet::Error) { ProjectLint::Catalogs.compile(declaration) }
      assert_includes error.message, "docker::#{wrapper} requires the docker class"
      error = assert_raises(Puppet::Error) { ProjectLint::Catalogs.compile("include docker\n" + declaration) }
      assert_includes error.message, "docker::#{wrapper} requires the nginx class"
    end
    catalog = ProjectLint::Catalogs.compile('include docker')
    assert_equal 'docker-ce', ProjectLint::Catalogs.resource(catalog, 'Package', 'docker')['name']
  end

  def test_global_configuration_validation_keeps_clear_failures
    error = assert_raises(Puppet::Error) do
      ProjectLint::Catalogs.compile("class { 'vnstat': p95_warning => 100, p95_critical => 50 }")
    end
    assert_includes error.message, 'vnstat p95_critical must be greater than or equal to p95_warning'
    catalog = ProjectLint::Catalogs.compile("class { 'vnstat': p95_warning => 100, p95_critical => 100 }")
    assert_equal '0600', ProjectLint::Catalogs.resource(catalog, 'Concat', '/etc/vnstat-monitoring.conf')['mode']
    error = assert_raises(Puppet::Error) do
      ProjectLint::Catalogs.compile("class { 'openitcockpit::server': grafana_password => Sensitive('replace-with-password'), webserver_directives => ['add_header X-Frame-Options DENY;'] }")
    end
    assert_includes error.message, 'webserver_directives must not set managed security headers'
  end
end
