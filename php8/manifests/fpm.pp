class php8::fpm(
        $pidfile = '',
        $errorlog = '',
        $ini_settings = [],
        $skip_default = false
    ) {

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
        ensure  => true,
        enable  => false,
        require => Package["php8.${minor_version}-fpm"]
    }

    /* Reload systemd deamon */
    exec { "php8_${minor_version}_systemd_daemon_reload":
        command     => 'systemctl daemon-reload',
        refreshonly => true,
        require     => Package['systemd']
    }

    /* Create drop in for Nginx service */
    if (defined(Class['nginx'])) {
        basic_settings::systemd_drop_in { 'nginx_php_dependency':
            target_unit     => 'nginx.service',
            unit            => {
                'After'     => "php8.${minor_version}-fpm.service",
                'BindsTo'   => "php8.${minor_version}-fpm.service"
            },
            daemon_reload   => "php8_${minor_version}_systemd_daemon_reload",
            require         => Class['nginx']
        }
    }

    /* Create drop in for PHP FPM service */
    basic_settings::systemd_drop_in { "php8_${minor_version}_nice":
        target_unit     => "php8.${minor_version}-fpm.service",
        service         => {
            'Nice' => "-${nginx::nice_level}"
        },
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
        mode    => '0770',
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

    if (!$skip_default) {
        /* Install php FPM package */
        package { 'php-fpm':
            ensure  => installed,
            require => Package["php8.${minor_version}-fpm"]
        }

        /* Install php package */
        package { ['php', "php8.${minor_version}"]:
            ensure  => installed,
            require => [Package['php-fpm'], Package["php8.${minor_version}-fpm"]]
        }

        /* Change PHP version */
        exec { 'php_set_default_version':
            command     => "update-alternatives --set php /usr/bin/php8.${minor_version}",
            refreshonly => true,
            require     => Package["php8.${minor_version}"],
            subscribe   => Package["php8.${minor_version}"]
        }
    } else {
        /* Install php package */
        package { ["php8.${minor_version}"]:
            ensure  => installed,
            require => [Package['php-fpm'], Package["php8.${minor_version}-fpm"]]
        }
    }
}
