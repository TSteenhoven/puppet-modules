class nginx(
        $run_user                   = 'www-data',
        $run_group                  = 'www-data',
        $keepalive_requests         = 1000,
        $keepalive_timeout          = '75s',
        $types_hash_max_size        = 2048,
        $global_directives          = [],
        $events_directives          = [],
        $http_directives            = [],
        $ssl_protocols              = 'TLSv1.2 TLSv1.3',
        $ssl_prefer_server_ciphers  = false,
        $nice_level                 = 10,
        $limit_file                 = 10000
    ) {

    /* Install Nginx */
    package { 'nginx':
        ensure => installed
    }

    /* Disable service */
    service { 'nginx':
        ensure  => undef,
        enable  => false,
        require => Package['nginx']
    }

    /* Reload systemd deamon */
    exec { 'nginx_systemd_daemon_reload':
        command     => 'systemctl daemon-reload',
        refreshonly => true,
        require     => Package['systemd']
    }

    /* Create drop in for services target */
    basic_settings::systemd_drop_in { 'nginx_dependency':
        target_unit     => "${basic_settings::cluster_id}-services.target",
        unit            => {
            'BindsTo'   => 'nginx.service'
        },
        daemon_reload   => 'nginx_systemd_daemon_reload',
        require         => Basic_settings::Systemd_target["${basic_settings::cluster_id}-services"]
    }

    /* Create drop in for nginx service */
    basic_settings::systemd_drop_in { 'nginx_settimgs':
        target_unit     => 'nginx.service',
        unit            => {
            'OnFailure' => 'notify-failed@%i.service'
        },
        service         => {
            'ExecStartPre'  => "/usr/bin/chown -R ${run_user}:${run_group} /var/cache/nginx",
            'Nice'          => "-${nice_level}",
            'LimitNOFILE'   => $limit_file,
        },
        daemon_reload   => 'nginx_systemd_daemon_reload',
        require         => Package['nginx']
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

    /* Create sites connfig directory */
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
