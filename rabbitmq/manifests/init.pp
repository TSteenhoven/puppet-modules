class rabbitmq(
        Optional[String]    $target     = 'services',
        Optional[Integer]   $nice_level = 12,
        Optional[Integer]   $limit_file = 10000
    ) {

    /* Install erlang */
    package { 'erlang-base':
        ensure => installed
    }

    /* Install rabbitmq */
    package { 'rabbitmq-server':
        ensure => installed,
        require => Package['erlang-base']
    }

    /* Disable service */
    if (defined(Package['systemd'])) {
        /* Disable service */
        service { 'rabbitmq-server':
            ensure  => undef,
            enable  => false,
            require => Package['rabbitmq-server']
        }

        /* Reload systemd deamon */
        exec { 'rabbitmq_systemd_daemon_reload':
            command     => '/usr/bin/systemctl daemon-reload',
            refreshonly => true,
            require     => Package['systemd']
        }

        /* Create drop in for x target */
        if (defined(Class['basic_settings::systemd'])) {
            basic_settings::systemd_drop_in { 'rabbitmq_dependency':
                target_unit     => "${basic_settings::systemd::cluster_id}-${target}.target",
                unit            => {
                    'BindsTo'   => 'rabbitmq-server.service'
                },
                daemon_reload   => 'rabbitmq_systemd_daemon_reload',
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
        basic_settings::systemd_drop_in { 'rabbitmq_settings':
            target_unit     => 'rabbitmq-server.service',
            unit            => $unit,
            service         => {
                'LimitNOFILE'       => $limit_file,
                'Nice'              => "-${nice_level}",
                'PrivateDevices'    => 'true',
                'PrivateTmp'        => 'true',
                'ProtectHome'       => 'true',
                'ProtectSystem'     => 'full',
            },
            daemon_reload   => 'rabbitmq_systemd_daemon_reload',
            require         => Package['rabbitmq-server']
        }
    }

    /* Create config directory */
    file { 'rabbitmq_config_dir':
        path    => '/etc/rabbitmq/conf.d',
        ensure  => directory,
        purge   => true,
        force   => true,
        recurse => true,
        owner   => 'rabbitmq',
        group   => 'rabbitmq',
        mode    => '0770',
        require => Package['rabbitmq-server']
    }

    /* Create ssl directory */
    file { 'rabbitmq_ssl':
        path    => '/etc/rabbitmq/ssl',
        ensure  => directory,
        owner   => 'rabbitmq',
        group   => 'rabbitmq',
        mode    => '0770',
        require => Package['rabbitmq-server']
    }
}
