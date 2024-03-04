class basic_settings::apt_services(
) {

    /* Ensure that apt-daily timers is always running */
    service { ['apt-daily.timer', 'apt-daily-upgrade.timer']:
        ensure      => running,
        enable      => true,
        require     => Package['systemd']
    }

    if (defined(Class['basic_settings::message'])) {
        /* Reload systemd deamon */
        exec { 'apt_services_systemd_daemon_reload':
            command         => 'systemctl daemon-reload',
            refreshonly     => true,
            require         => Package['systemd']
        }

        /* Create drop in for APT service */
        basic_settings::systemd_drop_in { 'apt_daily_upgrade_notify_failed':
            target_unit     => 'apt-daily.service',
            unit            => {
                'OnFailure' => 'notify-failed@%i.service'
            },
            daemon_reload   => 'apt_services_systemd_daemon_reload'
        }

        /* Create drop in for APT upgrade service */
        basic_settings::systemd_drop_in { 'apt_daily_upgrade_notify_failed':
            target_unit     => 'apt-daily.service',
            unit            => {
                'OnFailure' => 'notify-failed@%i.service'
            },
            daemon_reload   => 'apt_services_systemd_daemon_reload'
        }
    }
}
