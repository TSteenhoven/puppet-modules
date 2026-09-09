require_relative 'test_helper'
require_relative 'support/catalogs'
require_relative 'support/scenarios'

class CatalogTest < Minitest::Test
  def test_representative_compositions_cover_every_first_party_module
    ProjectLint::Scenarios::ALL.each do |name, code|
      catalog = ProjectLint::Catalogs.compile(code)
      assert_operator catalog.fetch('resources').length, :>, 0, name
    end
  end

  def test_compose_parent_guard_cleanup_and_environment_source_precedence
    assert_raises(Puppet::Error) do
      ProjectLint::Catalogs.compile("docker::compose { 'synthetic': compose_source => 'puppet:///modules/profile/compose.yml' }")
    end
    cleanup = ProjectLint::Catalogs.compile("docker::compose { 'synthetic': ensure => absent }")
    assert_equal 'absent', ProjectLint::Catalogs.resource(cleanup, 'File', '/opt/docker/synthetic')['ensure']
    base = "include basic_settings\ninclude docker\n"
    ["env_source => 'puppet:///modules/profile/env', env_content => Sensitive('unused')", "env_content => Sensitive('APP_SECRET=replace-with-secret')"].each do |attributes|
      catalog = ProjectLint::Catalogs.compile(base + "docker::compose { 'synthetic': compose_source => 'puppet:///modules/profile/compose.yml', #{attributes} }")
      file = ProjectLint::Catalogs.resource(catalog, 'File', '/opt/docker/synthetic/.env')
      assert_equal '0600', file['mode']
      if attributes.start_with?('env_source')
        assert_nil file['content']
        assert_equal ['puppet:///modules/profile/env'], Array(file['source'])
      else
        assert_nil file['source']
        assert file['content']
      end
    end
    assert_raises(Puppet::Error) do
      ProjectLint::Catalogs.compile("include nginx\ndocker::compose_proxy { 'synthetic': compose_source => 'puppet:///modules/profile/compose.yml', proxy_port => 8443, server_name => 'host.example.org' }")
    end
  end

  def test_base_catalog_has_explicit_private_file_ownership
    catalog = ProjectLint::Catalogs.compile('include basic_settings')
    locale = ProjectLint::Catalogs.resource(catalog, 'File', '/etc/default/locale')
    assert_equal 'root', locale['owner']
    assert_equal 'root', locale['group']
    sudoers = ProjectLint::Catalogs.resource(catalog, 'File', '/etc/sudoers.d')
    assert_equal '0440', sudoers['mode']
    assert_equal true, sudoers['recurse']
  end

  def test_login_user_keeps_directory_and_file_states_with_and_without_a_home_source
    %w[present absent].product([false, true]).each do |state, source|
      catalog = ProjectLint::Catalogs.compile(<<~PUPPET)
        basic_settings::login_user { 'synthetic':
          gid             => 2000,
          home            => '/home/synthetic',
          password        => Sensitive('!!'),
          uid             => 2000,
          authorized_keys => ['ssh-ed25519 replace-with-key'],
          bash_aliases    => 'alias ll="ls -l"',
          bash_profile    => 'export EDITOR=vi',
          bashrc          => 'umask 077',
          ensure          => #{state},
          home_source     => #{source ? "'puppet:///modules/profile/home'" : 'undef'},
          private_key     => 'puppet:///modules/profile/private.key',
        }
      PUPPET
      %w[/home/synthetic /home/synthetic/.ssh].each do |path|
        actual = ProjectLint::Catalogs.resource(catalog, 'File', path)['ensure']
        state == 'present' ? assert_equal('directory', actual) : assert_nil(actual)
      end
      %w[.ssh/authorized_keys .ssh/private.key .profile .bashrc .bash_aliases].each do |path|
        attributes = ProjectLint::Catalogs.resource(catalog, 'File', "/home/synthetic/#{path}")
        assert_equal state, attributes['ensure']
        assert_equal '0600', attributes['mode']
      end
      actual = ProjectLint::Catalogs.resource(catalog, 'File', '/home/synthetic')['source']
      source ? assert_equal(['puppet:///modules/profile/home'], Array(actual)) : assert_nil(actual)
      assert_equal state, ProjectLint::Catalogs.resource(catalog, 'User', 'synthetic')['ensure']
    end
  end

  def test_package_policy_flags_remain_last_after_conflicting_caller_options
    options = ['--no-install-recommends', '--install-recommends', '-t', 'stable']
    catalog = ProjectLint::Catalogs.compile("class { 'basic_settings::systemd': install_options => ['--no-install-recommends', '--install-recommends', '-t', 'stable'] }")
    actual = ProjectLint::Catalogs.resource(catalog, 'Package', 'systemd')['install_options']
    assert_equal options + ['--no-install-recommends', '--no-install-suggests'], actual
  end

  def test_proxmox_rejects_missing_or_unsupported_platform_context
    error = assert_raises(Puppet::Error) { ProjectLint::Catalogs.compile('include proxmox') }
    assert_includes error.message, 'requires the basic_settings class'
    ['11', '13'].each do |release|
      error = assert_raises(Puppet::Error) do
        ProjectLint::Catalogs.compile('include basic_settings\ninclude proxmox'.gsub('\\n', "\n"), platform: ProjectLint::Catalogs.facts(release: release))
      end
      assert_includes error.message, 'supports only Debian 12'
    end
  end

  def test_standalone_mysql_uses_the_structured_fqdn_fact_for_backup_labels
    catalog = ProjectLint::Catalogs.compile(ProjectLint::Scenarios::ALL.fetch('database_standalone'))
    content = ProjectLint::Catalogs.resource(catalog, 'File', '/etc/default/automysqlbackup.conf')['content']
    content = content.unwrap if content.respond_to?(:unwrap)
    assert_includes content.to_s, "CONFIG_mysql_dump_host_friendly='host.example.org'"
  end

  def test_real_stdlib_escaping_preserves_nested_shell_words_and_sql_semicolons
    value = %q(SELECT 'space quote' "$literal"; $(printf injected) `printf injected`)
    # Quote only the Puppet literal here; the actual module function supplies each shell parsing boundary.
    literal = "'" + value.gsub(/[\\']/) { |character| "\\#{character}" } + "'"
    catalog = ProjectLint::Catalogs.compile(<<~PUPPET)
      $value = #{literal}
      $word_shell = stdlib::shell_escape($value)
      $script = "/usr/bin/printf %s \${word_shell}"
      $script_shell = stdlib::shell_escape($script)
      file { '/tmp/synthetic-command': content => "/bin/sh -c \${script_shell}", owner => 'root', group => 'root', mode => '0600' }
    PUPPET
    command = ProjectLint::Catalogs.resource(catalog, 'File', '/tmp/synthetic-command')['content']
    stdout, stderr, status = Open3.capture3('/bin/sh', '-c', command)
    assert status.success?
    assert_empty stderr
    assert_equal value, stdout
  end

  def test_web_database_and_ssh_catalog_keeps_runtime_access
    catalog = ProjectLint::Catalogs.compile(<<~'PUPPET')
      include basic_settings
      include nginx
      include ssh
      class { 'mysql': automysqlbackup_password => Sensitive('replace-with-password') }
    PUPPET
    %w[/var/cache/nginx /var/log/nginx].each do |path|
      attributes = ProjectLint::Catalogs.resource(catalog, 'File', path)
      assert_equal '0750', attributes['mode']
      assert_equal 'www-data', attributes['owner']
      assert_equal 'www-data', attributes['group']
    end
    assert_equal '0600', ProjectLint::Catalogs.resource(catalog, 'File', '/etc/nginx/nginx.conf')['mode']
    assert_equal ['--no-install-recommends', '--no-install-suggests'], ProjectLint::Catalogs.resource(catalog, 'Package', 'mysql-server')['install_options']
    assert_equal 'root', ProjectLint::Catalogs.resource(catalog, 'File', '/etc/issue.net')['owner']
  end

  def test_nginx_secure_default_opt_out_and_custom_header_keep_one_public_setting
    { 'true' => 'nosniff', 'false' => nil, "'synthetic-policy'" => 'synthetic-policy' }.each do |value, expected|
      catalog = ProjectLint::Catalogs.compile("include nginx\nnginx::server { 'host.example.org': docroot => '/var/www/example', x_content_type_options => #{value} }")
      content = ProjectLint::Catalogs.resource(catalog, 'File', '/etc/nginx/conf.d/host.example.org.conf')['content']
      if expected
        assert_includes content, expected
        assert_includes content, 'X-Content-Type-Options'
      else
        refute_includes content, 'X-Content-Type-Options'
      end
    end
  end

  def test_firmware_package_policy_with_and_without_secure_boot
    [false, true].each do |secure_boot|
      platform = ProjectLint::Catalogs.facts(secure_boot: secure_boot).merge('is_virtual' => false, 'virtual' => 'physical')
      catalog = ProjectLint::Catalogs.compile('include basic_settings', platform: platform)
      assert_equal ['--no-install-recommends', '--no-install-suggests'], ProjectLint::Catalogs.resource(catalog, 'Package', 'fwupd')['install_options']
      if secure_boot
        assert_equal ['--no-install-recommends', '--no-install-suggests'], ProjectLint::Catalogs.resource(catalog, 'Package', 'fwupd-signed')['install_options']
      end
    end
  end

  def test_optional_source_and_content_contract
    base = "class { 'basic_settings': monitoring_package => 'openitcockpit', monitoring_package_install => true }\n"
    source = ProjectLint::Catalogs.compile(base + "basic_settings::monitoring_custom { 'synthetic': source => 'puppet:///modules/profile/check_example' }")
    file = ProjectLint::Catalogs.resource(source, 'File', '/etc/openitcockpit-agent/plugins/check_synthetic')
    assert_equal ['puppet:///modules/profile/check_example'], Array(file['source'])
    assert_nil file['content']
    content = ProjectLint::Catalogs.compile(base + "basic_settings::monitoring_custom { 'synthetic': content => '#!/bin/sh' }")
    file = ProjectLint::Catalogs.resource(content, 'File', '/etc/openitcockpit-agent/plugins/check_synthetic')
    assert_equal '#!/bin/sh', file['content']
    assert_nil file['source']
    assert_raises(Puppet::Error) do
      ProjectLint::Catalogs.compile(base + "basic_settings::monitoring_custom { 'synthetic': content => '#!/bin/sh', source => 'puppet:///modules/profile/check_example' }")
    end
  end

  def test_naemon_package_guard_and_shared_configuration_permissions
    assert_raises(Puppet::Error) { ProjectLint::Catalogs.compile('include naemon') }
    catalog = ProjectLint::Catalogs.compile(<<~'PUPPET')
      include basic_settings
      package { 'openitcockpit':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
      include naemon
    PUPPET
    attributes = ProjectLint::Catalogs.resource(catalog, 'File', '/opt/openitc/etc/nagios/nagios.cfg.d')
    assert_equal 'nagios', attributes['owner']
    assert_equal 'www-data', attributes['group']
    assert_equal '0660', attributes['mode']
    assert_equal false, ProjectLint::Catalogs.resource(catalog, 'Service', 'naemon')['enable']
  end

  def test_ubuntu_motd_package_and_network_dispatcher
    catalog = ProjectLint::Catalogs.compile("class { 'basic_settings': firewall_package => 'iptables' }", platform: ProjectLint::Catalogs.facts(os: 'Ubuntu', release: '24.04'))
    attributes = ProjectLint::Catalogs.resource(catalog, 'Package', 'update-motd')
    assert_equal ['--no-install-recommends', '--no-install-suggests'], attributes['install_options']
    dispatcher = ProjectLint::Catalogs.resource(catalog, 'File', 'firewall_networkd_dispatcher')
    assert_equal 'root', dispatcher['owner']
    assert_equal 'root', dispatcher['group']
    assert dispatcher['content'].start_with?("#!/bin/sh\n")
    _, _, status = Open3.capture3('/bin/sh', '-n', stdin_data: dispatcher['content'])
    assert status.success?
  end
end
