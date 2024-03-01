class basic_settings::puppet(
    $server_enable  = false,
    $server_package = 'puppetserver',
    $server_dir     = 'puppetserver'
) {

    /* Disable service */
    service { 'puppet':
        ensure  => undef,
        enable  => false
    }

    /* Create drop in for services target */
    if (defined(Class['basic_settings'])) {
        basic_settings::systemd_drop_in { 'puppet_dependency':
            target_unit     => "${basic_settings::cluster_id}-system.target",
            unit            => {
                'Wants'   => 'puppet.service'
            },
            require         => Basic_settings::Systemd_target["${basic_settings::cluster_id}-system"]
        }
    }

    /* Create drop in for puppet service */
    basic_settings::systemd_drop_in { 'puppet_settings':
        target_unit     => 'puppet.service',
        unit            => {
            'OnFailure' => 'notify-failed@%i.service'
        },
        service         => {
            'Nice'          => 19,
            'LimitNOFILE'   => 10000
        }
    }

    /* Do only the next steps when we are puppet server */
    if ($server_enable) {
        /* Disable service */
        service {  "${server_package}":
            ensure  => undef,
            enable  => false
        }

        /* Create drop in for services target */
        if (defined(Class['basic_settings'])) {
            basic_settings::systemd_drop_in { 'puppetserver_dependency':
                target_unit     => "${basic_settings::cluster_id}-system.target",
                unit            => {
                    'Wants'   => "${server_package}.service"
                },
                require         => Basic_settings::Systemd_target["${basic_settings::cluster_id}-system"]
            }
        }

        /* Create drop in for puppet server service */
        basic_settings::systemd_drop_in { 'puppetserver_settings':
            target_unit     => "${server_package}.service",
            unit            => {
                'OnFailure' => 'notify-failed@%i.service'
            },
            service         => {
                'Nice'          => '-8',
            }
        }

        /* Create systemd puppet server clean reports service */
        basic_settings::systemd_service { 'puppetserver-clean-reports':
            description => 'Clean puppetserver reports service',
            service     => {
                'Type'      => 'oneshot',
                'User'      => 'puppet',
                'ExecStart' => "/usr/bin/find /var/lib/${server_dir}/reports -type f -name '*.yaml' -ctime +1 -delete",
                'Nice'      => '19'
            },
        }

        /* Create systemd puppet server clean reports timer */
        basic_settings::systemd_timer { 'puppetserver-clean-reports':
            description => 'Clean puppetserver reports timer',
            timer       => {
                'OnCalendar' => '*-*-* 10:00'
            }
        }

        /* Create drop in for puppet service */
        basic_settings::systemd_drop_in { 'puppet_puppetserver_dependency':
            target_unit     => 'puppet.service',
            unit         => {
                'After'     => "${server_package}.service",
                'BindsTo'   => "${server_package}.service"
            }
        }
    }
}
