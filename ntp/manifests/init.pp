
class ntp(
        $pools = [
            "0.${basic_settings::os_parent}.pool.ntp.org",
            "1.${basic_settings::os_parent}.pool.ntp.org",
            "2.${basic_settings::os_parent}.pool.ntp.org",
            "3.${basic_settings::os_parent}.pool.ntp.org",
        ]
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

        /* Create log dir */
        file { '/var/log/ntpsec':
            ensure  => directory,
            owner   => 'ntpsec',
            group   => 'ntpsec',
            mode    => '0600',
            require => Package['ntpsec']
        }

        /* Set config file */
        file { '/etc/ntpsec/ntp.conf':
            ensure  => file,
            content => template('ntp/ntp-conf'),
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            require => Package['ntpsec']
        }

        /* Disable service */
        service { 'ntpsec':
            ensure      => true,
            enable      => false,
            require     => Package['ntpsec'],
            subscribe   => File['/etc/ntpsec/ntp.conf']
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
