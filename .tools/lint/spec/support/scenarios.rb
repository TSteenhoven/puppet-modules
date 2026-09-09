module ProjectLint
  # Catalog-only scenarios cover every first-party module with synthetic identities and no downloads or application.
  module Scenarios
    BASE = 'include basic_settings'.freeze
    ALL = {
      'base' => BASE,
      'web' => <<~'PUPPET',
        include basic_settings
        include nginx
        include ssh
        include php8
        include php8::fpm
        php8::fpm_pool { 'synthetic': user => 'www-data' }
        include letsencrypt
        package { 'python3-certbot-nginx': install_options => ['--no-install-recommends', '--no-install-suggests'] }
        letsencrypt::certificate { 'host.example.org': domains => ['host.example.org'] }
        nginx::server { 'host.example.org': docroot => '/var/www/example' }
      PUPPET
      'database' => <<~'PUPPET',
        include basic_settings
        class { 'mysql': automysqlbackup_password => Sensitive('replace-with-password') }
        mysql::database { 'synthetic': ensure => present }
        mysql::user { 'synthetic': ensure => present, username => 'synthetic', password => 'replace-with-password' }
        mysql::grant { 'synthetic': ensure => present, database => 'synthetic', username => 'synthetic' }
      PUPPET
      'containers' => <<~'PUPPET',
        include basic_settings
        include docker
        include nginx
        docker::compose_proxy { 'synthetic':
          compose_source => 'puppet:///modules/profile/compose.yml',
          env_content => Sensitive('APP_SECRET=replace-with-secret'),
          proxy_port => 8443,
          server_name => 'host.example.org',
        }
      PUPPET
      'gitlab' => "include basic_settings\nclass { 'gitlab': root_password => 'replace-with-password' }",
      'database_standalone' => "class { 'mysql': automysqlbackup_password => Sensitive('replace-with-password') }",
      'monitored_services' => <<~'PUPPET',
        class { 'basic_settings': monitoring_package => 'openitcockpit', monitoring_package_install => true }
        class { 'mysql': automysqlbackup_password => Sensitive('replace-with-password') }
        include ssh
        include rabbitmq
        class { 'rabbitmq::management': admin_password => 'replace-with-password' }
      PUPPET
      'network' => <<~'PUPPET',
        include basic_settings
        include netplanio
        netplanio::ethernet { 'eth0': dhcp_enable => true, ip_version => '4' }
        include vnstat
        vnstat::ethernet { 'eth0': }
      PUPPET
      'rabbitmq' => <<~'PUPPET',
        include basic_settings
        include rabbitmq
        include rabbitmq::tcp
        class { 'rabbitmq::management': admin_password => 'replace-with-password' }
        rabbitmq::management_vhost { 'synthetic': }
      PUPPET
      'monitoring' => <<~'PUPPET',
        class { 'basic_settings': monitoring_package => 'openitcockpit', monitoring_package_install => true }
        include nginx
        include php8
        include php8::fpm
        include openitcockpit
        class { 'openitcockpit::server': grafana_password => Sensitive('replace-with-password') }
        include naemon
        naemon::host { 'synthetic': address => '192.0.2.20' }
      PUPPET
      'proxmox' => "include basic_settings\ninclude proxmox",
    }.freeze
  end
end
