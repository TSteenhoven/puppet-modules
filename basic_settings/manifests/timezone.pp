class basic_settings::timezone(
    $os_parent,
    $timezone,
    $ntp_extra_pools = [],
    $install_options = undef,
) {

    /* Reload systemd deamon */
    exec { 'systemd_timezone_daemon_reload':
        command => 'systemctl daemon-reload',
        refreshonly => true,
        require => Package['systemd']
    }

    /* Install package */
    package { 'systemd-timesyncd':
        ensure          => installed,
        install_options => $install_options
    }

    /* Systemd NTP settings */
    $ntp_all_pools = flatten($ntp_extra_pools, [
        "0.${os_parent}.pool.ntp.org",
        "1.${os_parent}.pool.ntp.org",
        "2.${os_parent}.pool.ntp.org",
        "3.${os_parent}.pool.ntp.org",
    ]);
    $ntp_list = join($ntp_all_pools, ' ')

    /* Create systemd timesyncd config  */
    file { '/etc/systemd/timesyncd.conf':
        ensure  => file,
        content  => template('basic_settings/systemd/timesyncd.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        notify  => Exec['systemd_timezone_daemon_reload'],
        require => Package['systemd-timesyncd']
    }

    /* Ensure that systemd-timesyncd is always running */
    service { 'systemd-timesyncd':
        ensure      => running,
        enable      => true,
        require     => File['/etc/systemd/timesyncd.conf'],
        subscribe   => File['/etc/systemd/timesyncd.conf']
    }

    /* Set timezoen */
    class { 'timezone':
        timezone    => $timezone,
        require     => File['/etc/systemd/timesyncd.conf']
    }

    /* Remove unnecessary packages */
    package { ['ntp', 'ntpdate', 'ntpsec']:
        ensure  => purged,
        require => Package['systemd-timesyncd']
    }
}
