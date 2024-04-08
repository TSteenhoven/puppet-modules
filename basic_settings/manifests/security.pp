class basic_settings::security(
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

    # Create default audit file */
    file { '/etc/audit/rules.d/audit.rules':
        ensure  => file,
        content => template('basic_settings/security/audit.rules'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service['auditd']
    }
}
