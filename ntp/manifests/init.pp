
class ntp(
        $servers = [
            '0.debian.pool.ntp.org',
            '1.debian.pool.ntp.org',
            '2.debian.pool.ntp.org',
            '3.debian.pool.ntp.org',
        ],
        $static_ips = [],
        $range_ips = []
    ) {

        /* Add network time procotol package */
        package { 'ntpsec':
            ensure => installed
        }

        /* Add network time procotol stats package */
        package { 'ntpstat':
            ensure  => installed,
            require => Package['ntpsec']
        }

        /* Set config file */
        file { '/etc/ntp.conf':
            ensure  => file,
            content => template('ntp/ntp-conf'),
            owner   => 'root',
            group   => 'ntpsec',
            mode    => '0750',
            require => Package['ntpsec']
        }

        /* Remove dhcp file */
        file { '/var/lib/ntp/ntp.conf.dhcp':
            ensure => absent
        }

        /* Disable service */
        service { 'ntpsec':
            ensure      => true,
            enable      => false,
            require     => Package['ntpsec'],
            subscribe   => File['/etc/ntp.conf']
        }

        /* Reload systemd deamon */
        exec { 'ntpsec_systemd_daemon_reload':
            command     => 'systemctl daemon-reload',
            refreshonly => true,
            require     => Package['systemd']
        }

        /* Create drop in for services target */
        basic_settings::systemd_drop_in { 'ntpsec_dependency':
            target_unit     => "${basic_settings::cluster_id}-system.target",
            unit            => {
                'Wants'   => 'ntpsec.service'
            },
            daemon_reload   => 'ntpsec_systemd_daemon_reload',
            require         => Basic_settings::Systemd_target["${basic_settings::cluster_id}-system"]
        }

        /* Create drop in for ntpsec service */
        basic_settings::systemd_drop_in { 'ntpsec_nice':
            target_unit     => 'ntpsec.service',
            service         => {
                'Nice' => '-19'
            },
            daemon_reload   => 'ntpsec_systemd_daemon_reload',
            require         => Package['ntpsec']
        }
    }
