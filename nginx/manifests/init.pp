# @summary Installs and configures the Nginx service baseline.
#
# This class installs Nginx, removes Apache, optionally installs the Certbot Nginx plugin, disables vendor service
# enablement under systemd, binds Nginx into the shared target ladder, applies service hardening, manages global Nginx
# configuration and owned config directories, prepares secure SSL/security fallback directories, and adds monitoring and
# logrotate integration.
#
# @example Install Nginx with default security.txt fallback settings
#   include nginx
#
# @param events_directives
#   Additional raw directives rendered in the `events` context.
#
# @param global_directives
#   Additional raw directives rendered at the global Nginx context.
#
# @param http_directives
#   Additional raw directives rendered in the `http` context.
#
# @param keepalive_requests
#   Value rendered for `keepalive_requests`.
#
# @param keepalive_timeout
#   Value rendered for `keepalive_timeout`.
#
# @param limit_file
#   `LimitNOFILE` value applied to the Nginx systemd drop-in.
#
# @param nice_level
#   Positive nice value converted to a negative service priority in the systemd drop-in.
#
# @param package
#   Nginx package flavor to install. `nginx` purges `nginx-full`; `nginx-full` installs both package names.
#
# @param run_group
#   Runtime group used for writable/cache paths and group-readable security.txt fallback files.
#
# @param run_user
#   Runtime user used for Nginx log and cache directories.
#
# @param securitytxt_contacts
#   Default security.txt contact list inherited by vhosts when they do not set vhost-specific contacts.
#
# @param securitytxt_enable
#   Global default controlling whether vhosts create a managed security.txt fallback.
#
# @param securitytxt_encryption
#   Optional global Encryption URL inherited by vhosts.
#
# @param securitytxt_expires_days
#   Number of days used to calculate security.txt `Expires` values.
#
# @param securitytxt_policy
#   Optional global Policy URL inherited by vhosts.
#
# @param securitytxt_preferred_languages
#   Optional global Preferred-Languages list inherited by vhosts.
#
# @param ssl_prefer_server_ciphers
#   Value rendered into global SSL configuration.
#
# @param ssl_protocols
#   Default TLS protocol string inherited by vhosts when they do not override it.
#
# @param target
#   `basic_settings::systemd` target suffix that should bind to `nginx.service`.
#
# @param types_hash_max_size
#   Value rendered for `types_hash_max_size`.
#
# @param variables_hash_bucket_size
#   Value rendered for `variables_hash_bucket_size`.
#
# @param variables_hash_max_size
#   Value rendered for `variables_hash_max_size`.
#
# @api public
class nginx (
  Array                       $events_directives               = [],
  Array                       $global_directives               = [],
  Array                       $http_directives                 = [],
  Integer                     $keepalive_requests              = 1000,
  String                      $keepalive_timeout               = '75s',
  Integer                     $limit_file                      = 10000,
  Integer                     $nice_level                      = 10,
  Enum['nginx', 'nginx-full'] $package                         = 'nginx',
  String                      $run_group                       = 'www-data',
  String                      $run_user                        = 'www-data',
  Optional[Array]             $securitytxt_contacts            = undef,
  Boolean                     $securitytxt_enable              = true,
  Optional[String]            $securitytxt_encryption          = undef,
  Integer                     $securitytxt_expires_days        = 365,
  Optional[String]            $securitytxt_policy              = undef,
  Optional[Array]             $securitytxt_preferred_languages = ['nl', 'en'],
  Boolean                     $ssl_prefer_server_ciphers       = true,
  String                      $ssl_protocols                   = 'TLSv1.2 TLSv1.3',
  String                      $target                          = 'services',
  Integer                     $types_hash_max_size             = 2048,
  Integer                     $variables_hash_bucket_size      = 128,
  Integer                     $variables_hash_max_size         = 2048,
) {
  # Set some values
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  $config = '/etc/nginx/conf.d'

  # Monitoring shares the service configuration path and uses Nginx binary defaults for the package prefix.
  $config_file = '/etc/nginx/nginx.conf'

  # Supply shared command tools for vhost cleanup and certificate monitoring.
  ensure_packages('coreutils', {
    'ensure'          => 'installed',
    'install_options' => ['--no-install-recommends', '--no-install-suggests'],
  })

  # Remove unnecessary package
  package { 'apache2':
    ensure => purged,
  }

  # Install Nginx
  case $package {
    'nginx-full': {
      # Install Nginx package
      package { ['nginx', 'nginx-full']:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['apache2'],
      }
    }
    default: {
      # Remove unnecessary package
      package { 'nginx-full':
        ensure => purged,
      }

      # Install Nginx package
      package { 'nginx':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['apache2', 'nginx-full'],
      }
    }
  }

  # Check if letsencrypt class is defined
  if (defined(Class['letsencrypt'])) {
    package { 'python3-certbot-nginx':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['apache2'],
    }
  }

  # Set PID file
  $pid = '/run/nginx.pid'

  # Shared targets control startup under systemd; otherwise Puppet enables and starts Nginx directly.
  $systemd_enable = defined(Package['systemd'])
  $service_ensure = $systemd_enable ? { true => undef, default => true }
  $service_enable = $systemd_enable ? { true => false, default => true }

  # Manage the Nginx service after its package is installed.
  service { 'nginx':
    ensure  => $service_ensure,
    enable  => $service_enable,
    require => Package['nginx'],
  }

  # Disable service
  if ($systemd_enable) {
    # Reload systemd deamon
    exec { 'nginx_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
      before      => Service['nginx'],
    }

    # Create drop in for x target
    if (defined(Class['basic_settings::systemd'])) {
      basic_settings::systemd_drop_in { 'nginx_dependency':
        target_unit   => "${basic_settings::systemd::cluster_id}-${target}.target",
        unit          => {
          'BindsTo'   => 'nginx.service',
        },
        daemon_reload => 'nginx_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-${target}"],
      }
    }

    # Get unit
    if ($monitoring_enable) {
      # Route unit failures through the configured monitoring notification service.
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }
    } else {
      # Leave unit failure hooks empty when monitoring is unavailable.
      $unit = {}
    }

    # Create drop in for nginx service
    basic_settings::systemd_drop_in { 'nginx_settings':
      target_unit   => 'nginx.service',
      unit          => $unit,
      service       => {
        'LimitNOFILE'             => $limit_file,
        'Nice'                    => "-${nice_level}",
        'PIDFile'                 => $pid,
        'PrivateDevices'          => 'true',
        'PrivateTmp'              => 'true',
        'ProtectClock'            => 'true',
        'ProtectHome'             => 'true',
        'ProtectHostname'         => 'true',
        'ProtectKernelModules'    => 'true',
        'ProtectKernelLogs'       => 'true',
        'ProtectKernelTunables'   => 'true',
        'ProtectControlGroups'    => 'true',
        'ProtectSystem'           => 'full',
        'SystemCallArchitectures' => 'native',
        'UMask'                   => '0077',
      },
      daemon_reload => 'nginx_systemd_daemon_reload',
      require       => Package['nginx'],
      before        => Exec['nginx_systemd_daemon_reload'],
    }

    # Older Linux kernels charge QUIC BPF maps against the service's locked-memory limit.
    @basic_settings::systemd_drop_in { 'nginx_quic':
      target_unit   => 'nginx.service',
      service       => {
        'LimitMEMLOCK' => 'infinity',
      },
      daemon_reload => 'nginx_systemd_daemon_reload',
      require       => Package['nginx'],
      notify        => Service['nginx'],
    }
  }

  # Create service check
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    basic_settings::monitoring_service { 'nginx': }

    # One executable serves all vhost registrations; only the main daemon configuration is templated.
    $monitoring_cert_packages = ['ca-certificates', 'dash', 'diffutils', 'grep', 'mawk', 'openssl']

    ensure_packages($monitoring_cert_packages, {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    })

    # Prepare the shared certificate check content and package dependencies.
    $monitoring_cert_required_packages = concat(
      $monitoring_cert_packages,
      ['coreutils', 'nginx'],
    )
    $nginx_config_shell = stdlib::shell_escape($config_file)
    $monitoring_cert_content = template('nginx/check_nginx_cert')
    $monitoring_cert_ensure = present
    $monitoring_cert_require = [
      File[$config_file, 'monitoring_location_plugins'],
      Package[$monitoring_cert_required_packages],
    ]
  } else {
    # Remove the shared certificate check when no supported monitoring backend is active.
    $monitoring_cert_content = undef
    $monitoring_cert_ensure = absent
    $monitoring_cert_require = undef
  }

  # Own one executable for all certificate registrations and remove it when monitoring is disabled.
  basic_settings::monitoring_custom { 'nginx_cert':
    ensure   => $monitoring_cert_ensure,
    content  => $monitoring_cert_content,
    register => false,
    require  => $monitoring_cert_require,
  }

  # Workers own the logs, and the local logrotate wrapper recreates them for this same runtime user.
  file { '/var/log/nginx':
    ensure  => directory,
    owner   => $run_user,
    group   => $run_group,
    mode    => '0750',
    require => Package['nginx'],
  }

  # Keep the cache traversable by the configured worker identity without granting access to other users.
  file { '/var/cache/nginx':
    ensure  => directory,
    owner   => $run_user,
    group   => $run_group,
    mode    => '0750',
    require => Package['nginx'],
  }

  # The privileged Nginx master loads configuration that may contain private upstream settings.
  file { $config_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template('nginx/global.conf'),
    notify  => Service['nginx'],
    require => Package['nginx'],
  }

  # Reload systemd as well as Nginx when retiring the shared QUIC configuration.
  $quic_notify = $systemd_enable ? {
    true    => [Exec['nginx_systemd_daemon_reload'], Service['nginx']],
    default => Service['nginx'],
  }

  # Own the configuration directories and purge retired vhosts and the last unused QUIC fragment.
  file { [$config, '/etc/nginx/sites-enabled']:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    purge   => true,
    force   => true,
    recurse => true,
    notify  => $quic_notify,
    require => Package['nginx'],
  }

  # HTTP/3 vhosts realize this single fragment because quic_bpf is valid only in the main context.
  @file { 'nginx_quic':
    ensure  => file,
    path    => "${config}/0-quic.main",
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => "# Managed by puppet\nquic_bpf on;\n",
    notify  => Service['nginx'],
    require => File[$config],
  }

  # Create snippets directory
  file { 'nginx_snippets':
    ensure  => directory,
    path    => '/etc/nginx/snippets',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Package['nginx'],
  }

  # Create security directory
  file { 'nginx_security':
    ensure  => directory,
    path    => '/etc/nginx/security',
    owner   => 'root',
    group   => $run_group,
    mode    => '0710',
    require => Package['nginx'],
  }

  # Create ssl directory
  file { 'nginx_ssl':
    ensure  => directory,
    path    => '/etc/nginx/ssl',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Package['nginx'],
  }

  # Create FastCGI config
  file { 'nginx_fastcgi_params':
    ensure => file,
    path   => '/etc/nginx/fastcgi_params',
    source => 'puppet:///modules/nginx/fastcgi_params',
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
    notify => Service['nginx'],
  }

  # Create FastCGI PHP config
  file { 'nginx_fastcgi_php':
    ensure  => file,
    path    => '/etc/nginx/snippets/fastcgi_php.conf',
    source  => 'puppet:///modules/nginx/fastcgi_php.conf',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => File['nginx_fastcgi_params', 'nginx_snippets'],
    notify  => Service['nginx'],
  }

  # Remove wrong FastCGI config
  file { ['/etc/nginx/fastcgi.conf', '/etc/nginx/snippets/fastcgi-php.conf', '/etc/nginx/snippets/fastcgi_params-php']:
    ensure  => absent,
    require => File['nginx_snippets'],
  }

  # Check if logrotate package exists
  if (defined(Package['logrotate'])) {
    basic_settings::io_logrotate { 'nginx':
      path           => '/var/log/nginx/*.log',
      frequency      => 'daily',
      compress_delay => true,
      create_user    => $run_user,
      rotate_post    => "if [ -f /var/run/nginx.pid ]; then\n\t\tkill -USR1 \"\$(/usr/bin/cat /var/run/nginx.pid)\"\n\tfi",
    }
  }
}
