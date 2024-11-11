class nginx (
  Array     $events_directives          = [],
  Array     $global_directives          = [],
  Array     $http_directives            = [],
  Boolean   $ssl_prefer_server_ciphers  = true,
  Integer   $keepalive_requests         = 1000,
  Integer   $limit_file                 = 10000,
  Integer   $nice_level                 = 10,
  Integer   $types_hash_max_size        = 2048,
  String    $keepalive_timeout          = '75s',
  String    $run_group                  = 'www-data',
  String    $run_user                   = 'www-data',
  String    $ssl_protocols              = 'TLSv1.2 TLSv1.3',
  String    $target                     = 'services'
) {
  # Remove unnecessary package
  package { 'apache2':
    ensure => purged,
  }

  # Install Nginx
  package { 'nginx':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
    require         => Package['apache2'],
  }

  # Set PID file
  $pid = '/run/nginx.pid'

  # Disable service
  if (defined(Package['systemd'])) {
    # Disable service
    service { 'nginx':
      ensure  => undef,
      enable  => false,
      require => Package['nginx'],
    }

    # Reload systemd deamon
    exec { 'nginx_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
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
    if (defined(Class['basic_settings::message'])) {
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }
    } else {
      $unit = {}
    }

    # Create drop in for nginx service
    basic_settings::systemd_drop_in { 'nginx_settings':
      target_unit   => 'nginx.service',
      unit          => $unit,
      service       => {
        'ExecStartPre'   => "/usr/bin/chown -R ${run_user}:${run_group} /var/cache/nginx",
        'LimitNOFILE'    => $limit_file,
        'Nice'           => "-${nice_level}",
        'PIDFile'        => $pid,
        'PrivateDevices' => 'true',
        'PrivateTmp'     => 'true',
        'ProtectHome'    => 'true',
        'ProtectSystem'  => 'full',
      },
      daemon_reload => 'nginx_systemd_daemon_reload',
      require       => Package['nginx'],
    }
  }

  # Create log file
  file { '/var/log/nginx':
    ensure  => directory,
    owner   => $run_user,
    require => Package['nginx'],
  }

  # Create nginx config file
  file { '/etc/nginx/nginx.conf':
    ensure  => file,
    content => template('nginx/global.conf'),
    notify  => Service['nginx'],
    require => Package['nginx'],
  }

  # Create sites config directory
  file { '/etc/nginx/conf.d':
    ensure  => directory,
    purge   => true,
    force   => true,
    recurse => true,
    require => Package['nginx'],
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

  # Create ssl directory
  file { 'nginx_ssl':
    ensure  => directory,
    path    => '/etc/nginx/ssl',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Package['nginx'],
  }

  # Create FastCGI PHP config
  file { 'nginx_fastcgi_php_conf':
    ensure  => file,
    path    => '/etc/nginx/snippets/fastcgi-php.conf',
    source  => 'puppet:///modules/nginx/fastcgi-php.conf',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => File['nginx_snippets'],
    notify  => Service['nginx'],
  }

  # Create FastCGI config
  file { 'nginx_fastcgi_conf':
    ensure  => file,
    path    => '/etc/nginx/fastcgi.conf',
    source  => 'puppet:///modules/nginx/fastcgi.conf',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => File['nginx_fastcgi_php_conf'],
    notify  => Service['nginx'],
  }

  # Check if logrotate package exists
  if (defined(Package['logrotate'])) {
    basic_settings::io_logrotate { 'nginx':
      path           => '/var/log/nginx/*.log',
      frequency      => 'daily',
      compress_delay => true,
      create_user    => $run_user,
      rotate_post    => "if [ -f /var/run/nginx.pid ]; then\n\t\tkill -USR1 `cat /var/run/nginx.pid`\n\tfi",
    }
  }
}
