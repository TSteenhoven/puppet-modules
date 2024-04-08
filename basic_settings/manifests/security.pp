class basic_settings::security(
    $mail_to        = 'root',
    $puppet_server  = false
) {

    /* Install default security packages */
    package { ['apparmor', 'auditd']:
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

    /* Do extra steps when Ubuntu */
    if ($operatingsystem == 'Ubuntu') {
        $network_interface = 'netplan'
    } else {
        $network_interface = 'systemd'
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

    # Create default audit file */
    file { '/etc/audit/rules.d/audit.rules':
        ensure  => file,
        content => template('basic_settings/security/audit.rules'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service['auditd']
    }

    if (defined(Package['systemd']) and defined(Class['basic_settings::message'])) {
        /* Create systemctl daemon reload */
        exec { 'security_systemd_daemon_reload':
            command         => 'systemctl daemon-reload',
            refreshonly     => true,
            require         => Package['systemd']
        }

        /* Create drop in for apparmor service */
        basic_settings::systemd_drop_in { 'apparmor_notify_failed':
            target_unit     => 'apparmor.service',
            unit            => {
                'OnFailure' => 'notify-failed@%i.service'
            },
            daemon_reload   => 'security_systemd_daemon_reload',
            require         => Package['apparmor']
        }

        /* Create drop in for auditd service */
        basic_settings::systemd_drop_in { 'auditd_notify_failed':
            target_unit     => 'auditd.service',
            unit            => {
                'OnFailure' => 'notify-failed@%i.service'
            },
            daemon_reload   => 'security_systemd_daemon_reload',
            require         => Package['auditd']
        }
    }
}
