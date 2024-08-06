class basic_settings::security(
    $mail_to                = 'root',
    $server_fdqn            = $fdqn
) {

    /* Install default security packages */
    package { ['apparmor', 'auditd', 'pwgen']:
        ensure  => installed
    }

    /* Enable apparmor service */
    service { 'apparmor':
        ensure  => true,
        enable  => true,
        require => Package['apparmor']
    }

    /* Enable apparmor service */
    service { 'auditd':
        ensure  => true,
        enable  => true,
        require => Package['auditd']
    }

    # Create auditd config file */
    file { '/etc/audit/auditd.conf':
        ensure  => file,
        content => template('basic_settings/security/auditd.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service['auditd']
    }

    /* Create rules dir */
    file { '/etc/audit/rules.d':
        ensure  => directory,
        recurse => true,
        force   => true,
        purge   => true,
        mode    => '0700'
    }

    # Create default audit rule file */
    file { '/etc/audit/rules.d/audit.rules':
        ensure  => file,
        content => template('basic_settings/security/audit.rules'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service['auditd'],
        require => File['/etc/audit/rules.d']
    }

    /* Check if we have systemd */
    if (defined(Package['systemd'])) {
        $systemd_enable = true
    } else {
        $systemd_enable = false
    }

    # Create main audit rule file */
    file { '/etc/audit/rules.d/10-main.rules':
        ensure  => file,
        content => template('basic_settings/security/main.rules'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service['auditd'],
        require => File['/etc/audit/rules.d']
    }

    # Create default audit file */
    file { '/usr/local/sbin/auditmail':
        ensure  => file,
        content => template('basic_settings/security/auditmail'),
        owner   => 'root',
        group   => 'root',
        mode    => '0700', # Only root
        notify  => Service['auditd']
    }

    /* Check if systemd and message class exists */
    if ($systemd_enable) {
        /* Create systemctl daemon reload */
        exec { 'security_systemd_daemon_reload':
            command         => '/usr/bin/systemctl daemon-reload',
            refreshonly     => true,
            require         => Package['systemd']
        }

        /* Create unit */
        if (defined(Class['basic_settings::message'])) {
            $unit = {
                'OnFailure' => 'notify-failed@%i.service'
            }

            /* Create drop in for apparmor service */
            basic_settings::systemd_drop_in { 'apparmor_notify_failed':
                target_unit     => 'apparmor.service',
                unit            => $unit,
                daemon_reload   => 'security_systemd_daemon_reload',
                require         => Package['apparmor']
            }
        } else {
            $unit = {}
        }

        /* Create drop in for auditd service */
        basic_settings::systemd_drop_in { 'auditd_settings':
            target_unit     => 'auditd.service',
            unit            => $unit,
            service         => {
                'PrivateTmp'    => 'true',
                'ProtectHome'   => 'false' # Important for monitoring home dirs
            },
            daemon_reload   => 'security_systemd_daemon_reload',
            require         => Package['auditd']
        }

        /* Create systemd service */
        basic_settings::systemd_service { 'auditmail':
            description => 'Audit mail service',
            unit        => $unit,
            service     => {
                'Type'          => 'oneshot',
                'User'          => 'root',
                'ExecStart'     => '/usr/local/sbin/auditmail',
                'Nice'          => '-20', # Important process
                'PrivateTmp'    => 'true',
                'ProtectHome'   => 'true',
                'ProtectSystem' => 'full'
            },
            daemon_reload   => 'security_systemd_daemon_reload',
        }

        /* Create systemd timer */
        basic_settings::systemd_timer { 'auditmail':
            description     => 'Audit mail timer',
            timer       => {
                'OnCalendar' => '*-*-* 0:30'
            },
            daemon_reload   => 'security_systemd_daemon_reload',
        }
    }
}
