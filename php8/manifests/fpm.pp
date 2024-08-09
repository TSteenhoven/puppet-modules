class php8::fpm(
        Optional[String]    $errorlog       = '',
        Optional[Hash]      $ini_settings   = {},
        Optional[String]    $pidfile        = ''
    ) {

    /* Merge given init settings with default settings */
    if (defined(Class['basic_settings::timezone'])) {
        $correct_ini_settings = stdlib::merge({
            'date.timezone' => $basic_settings::timezone::timezone
        }, $ini_settings)
    } else {
        $correct_ini_settings = $ini_settings
    }

    /* Get minor version from PHP init */
    $minor_version = $php8::minor_version

    /* Get correct pid file */
    if ($pidfile == '') {
        $correct_pidfile = "/run/php/php8.${minor_version}-fpm.pid"
    } else {
        $correct_pidfile = $pidfile
    }

    /* Get correct error file */
    if ($errorlog == '') {
        $correct_errorlog = "/var/log/php8.${minor_version}-fpm.log"
    } else {
        $correct_errorlog = $errorlog
    }

    /* Install package */
    package { "php8.${minor_version}-fpm":
        ensure  => installed,
        require => Class['php8'],
    }

    /* Disable service */
    service { "php8.${minor_version}-fpm":
        ensure  => undef,
        enable  => false,
        require => Package["php8.${minor_version}-fpm"]
    }

    /* Reload systemd deamon */
    exec { "php8_${minor_version}_systemd_daemon_reload":
        command     => '/usr/bin/systemctl daemon-reload',
        refreshonly => true,
        require     => Package['systemd']
    }

    /* Set service */
    $default_service = {
        'PrivateDevices'    => 'true',
        'PrivateTmp'        => 'true',
        'ProtectHome'       => 'true',
        'ProtectSystem'     => 'full'
    }

    /* Check if nginx class exists */
    if (defined(Class['nginx'])) {
        /* Remove unnecessary package */
        package { "libapache2-mod-php8.${minor_version}":
            ensure => purged
        }

        /* Create drop in for nginx service */
        basic_settings::systemd_drop_in { 'nginx_php_dependency':
            target_unit     => 'nginx.service',
            unit            => {
                'After'     => "php8.${minor_version}-fpm.service",
                'BindsTo'   => "php8.${minor_version}-fpm.service"
            },
            daemon_reload   => "php8_${minor_version}_systemd_daemon_reload",
            require         => Class['nginx']
        }

        /* Set service */
        $service = stdlib::merge({
            'Nice' => "-${nginx::nice_level}"
        }, $default_service)
    } else {
        $default = $default_service
    }

    /* Create drop in for PHP FPM service */
    basic_settings::systemd_drop_in { "php8_${minor_version}_settings":
        target_unit     => "php8.${minor_version}-fpm.service",
        unit            => {
            'OnFailure' => 'notify-failed@%i.service'
        },
        service         => $service,
        daemon_reload   => "php8_${minor_version}_systemd_daemon_reload",
        require         => Package["php8.${minor_version}-fpm"]
    }

    /* Create PHP FPM config */
    file { "/etc/php/8.${minor_version}/fpm/php-fpm.conf":
        ensure  => file,
        content => template('php8/fpm-global.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service["php8.${minor_version}-fpm"],
        require => Package["php8.${minor_version}-fpm"]
    }

    /* Create PHP FPM pool */
    file { "/etc/php/8.${minor_version}/fpm/pool.d":
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0700',
        purge   => true,
        force   => true,
        recurse => true
    }

    /* Create PHP custom settings */
    file { "/etc/php/8.${minor_version}/fpm/conf.d/99-custom-settings.ini":
        ensure  => file,
        content => template('php8/settings-template.ini'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600'
    }

    /* Check if logrotate package exists */
    if (defined(Package['logrotate'])) {
        basic_settings::io_logrotate { "php8.${minor_version}-fpm":
            path            => "/var/log/php8.${minor_version}-fpm.log",
            handle          => 'weekly',
            compress_delay  => true,
            rotate_post     => "if [ -x /usr/lib/php/php8.${minor_version}-fpm-reopenlogs ]; then\n\t\t/usr/lib/php/php8.${minor_version}-fpm-reopenlogs;\n\tfi"
        }
    }
}
