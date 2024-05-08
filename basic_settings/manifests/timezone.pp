class basic_settings::timezone(
    $timezone,
    $ntp_extra_pools = [],
    $install_options = undef,
) {

    if (defined(Package['systemd'])) {
        /* Reload systemd deamon */
        exec { 'systemd_timezone_daemon_reload':
            command => '/usr/bin/systemctl daemon-reload',
            refreshonly => true,
            require => Package['systemd']
        }

        /* Install package */
        package { 'systemd-timesyncd':
            ensure          => installed,
            install_options => $install_options
        }

        /* Get OS name */
        case $operatingsystem {
            'Ubuntu': {
                $ntp_all_pools = flatten($ntp_extra_pools, [
                    '0.ubuntu.pool.ntp.org',
                    '1.ubuntu.pool.ntp.org',
                    '2.ubuntu.pool.ntp.org',
                    '3.ubuntu.pool.ntp.org',
                ])
            }
            'Debian': {
                $ntp_all_pools = flatten($ntp_extra_pools, [
                    '0.debian.pool.ntp.org',
                    '1.debian.pool.ntp.org',
                    '2.debian.pool.ntp.org',
                    '3.debian.pool.ntp.org',
                ])
            }
            default: {
                $ntp_all_pools = []
            }
        }

        /* Systemd NTP settings */
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

        /* Remove unnecessary packages */
        package { ['chrony', 'ntp', 'ntpdate', 'ntpsec']:
            ensure  => purged,
            require => Package['systemd-timesyncd']
        }
    }

    /* Set timezoen */
    class { 'timezone':
        timezone    => $timezone,
        require     => File['/etc/systemd/timesyncd.conf']
    }
}
