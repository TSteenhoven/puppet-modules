class nginx(
        Optional[Array]     $events_directives          = [],
        Optional[Array]     $global_directives          = [],
        Optional[Array]     $http_directives            = [],
        Optional[Boolean]   $ssl_prefer_server_ciphers  = true,
        Optional[Integer]   $keepalive_requests         = 1000,
        Optional[Integer]   $limit_file                 = 10000
        Optional[Integer]   $nice_level                 = 10,
        Optional[Integer]   $types_hash_max_size        = 2048,
        Optional[String]    $keepalive_timeout          = '75s',
        Optional[String]    $run_group                  = 'www-data',
        Optional[String]    $run_user                   = 'www-data',
        Optional[String]    $ssl_protocols              = 'TLSv1.2 TLSv1.3',
        Optional[String]    $target                     = 'services',
    ) {

    /* Remove unnecessary package */
    package { 'apache2':
        ensure => purged
    }

    /* Install Nginx */
    package { 'nginx':
        ensure => installed,
        require => Package['apache2']
    }

    /* Set PID file */
    $pid = '/run/nginx.pid'

    /* Disable service */
    if (defined(Package['systemd'])) {
        /* Disable service */
        service { 'nginx':
            ensure  => undef,
            enable  => false,
            require => Package['nginx']
        }

        /* Reload systemd deamon */
        exec { 'nginx_systemd_daemon_reload':
            command     => '/usr/bin/systemctl daemon-reload',
            refreshonly => true,
            require     => Package['systemd']
        }

        /* Create drop in for x target */
        if (defined(Class['basic_settings::systemd'])) {
            basic_settings::systemd_drop_in { 'nginx_dependency':
                target_unit     => "${basic_settings::systemd::cluster_id}-${target}.target",
                unit            => {
                    'BindsTo'   => 'nginx.service'
                },
                daemon_reload   => 'nginx_systemd_daemon_reload',
                require         => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-${target}"]
            }
        }

        /* Get unit */
        if (defined(Class['basic_settings::message'])) {
            $unit = {
                'OnFailure' => 'notify-failed@%i.service'
            }
        } else {
            $unit = {}
        }

        /* Create drop in for nginx service */
        basic_settings::systemd_drop_in { 'nginx_settings':
            target_unit     => 'nginx.service',
            unit            => $unit,
            service         => {
                'ExecStartPre'      => "/usr/bin/chown -R ${run_user}:${run_group} /var/cache/nginx",
                'LimitNOFILE'       => $limit_file,
                'Nice'              => "-${nice_level}",
                'PIDFile'           => $pid,
                'PrivateDevices'    => 'true',
                'PrivateTmp'        => 'true',
                'ProtectHome'       => 'true',
                'ProtectSystem'     => 'full',
            },
            daemon_reload   => 'nginx_systemd_daemon_reload',
            require         => Package['nginx']
        }
    }

    /* Create log file */
    file { '/var/log/nginx':
        ensure  => directory,
        owner   => $run_user,
        require => Package['nginx']
    }

    /* Create nginx config file */
    file { '/etc/nginx/nginx.conf':
        ensure  => file,
        content => template('nginx/global.conf'),
        notify  => Service['nginx'],
        require => Package['nginx']
    }

    /* Create sites config directory */
    file { '/etc/nginx/conf.d':
        ensure  => directory,
        purge   => true,
        force   => true,
        recurse => true,
        require => Package['nginx']
    }

    /* Create snippets directory */
    file { 'nginx_snippets':
        path    => '/etc/nginx/snippets',
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0770',
        require => Package['nginx']
    }

    /* Create ssl directory */
    file { 'nginx_ssl':
        path    => '/etc/nginx/ssl',
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0770',
        require => Package['nginx']
    }

    /* Create FastCGI PHP config */
    file { 'nginx_fastcgi_php_conf':
        path    => '/etc/nginx/snippets/fastcgi-php.conf',
        ensure  => file,
        source  => 'puppet:///modules/nginx/fastcgi-php.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => File['nginx_snippets'],
        notify  => Service['nginx']
    }

    /* Create FastCGI config */
    file { 'nginx_fastcgi_conf':
        path    => '/etc/nginx/fastcgi.conf',
        ensure  => file,
        source  => 'puppet:///modules/nginx/fastcgi.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => File['nginx_fastcgi_php_conf'],
        notify  => Service['nginx']
    }
}
