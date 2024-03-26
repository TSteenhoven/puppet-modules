class basic_settings::network(
    $firewall_package,
    $install_options = undef,
) {

    /* Based on firewall package do special commands */
    case $firewall_package {
        'nftables': {
            $firewall_command = 'systemctl is-active --quiet nftables.service && nft --file /etc/firewall.conf'
            package { ['iptables', 'firwalld']:
                ensure => purged
            }
        }
        'iptables': {
            $firewall_command = 'iptables-restore < /etc/firewall.conf'
            package { ['nftables', 'firwalld']:
                ensure => purged
            }
        }
        'firewalld': {
            $firewall_command = ''
        }
    }

    /* Install package */
    package { "${firewall_package}":
        ensure          => installed,
        install_options => $install_options
    }

    /* Remove unnecessary packages */
    package { 'ifupdown':
        ensure  => purged
    }

    /* Install package */
    package { ['dnsutils', 'ethtool', 'iputils-ping', 'mtr-tiny', 'netcat']:
        ensure => installed,
        require => Package['ifupdown']
    }

    /* If we need to install netplan */
    case $operatingsystem {
        'Ubuntu': {
            package { 'netplan.io':
                ensure  => installed
            }
        }
        default: {
            package { 'netplan.io':
                ensure  => purged
            }
        }
    }

    /* Reload systemd deamon */
    if (defined(Class['basic_settings::systemd']) or defined(Class['basic_settings::message'])) {
        exec { 'network_firewall_systemd_daemon_reload':
            command         => 'systemctl daemon-reload',
            refreshonly     => true,
            require         => Package['systemd']
        }
    }

    /* Start nftables */
    if ($firewall_package == 'nftables' or $firewall_package == 'firewalld') {
        service { "${firewall_package}":
            ensure      => running,
            enable      => true,
            require     => Package[$firewall_package]
        }

        if (defined(Class['basic_settings::message'])) {
            /* Create drop in for firewall service */
            basic_settings::systemd_drop_in { "${firewall_package}_notify_failed":
                target_unit     => "${firewall_package}.service",
                unit            => {
                    'OnFailure' => 'notify-failed@%i.service'
                },
                daemon_reload   => 'network_firewall_systemd_daemon_reload',
                require         => Package[$firewall_package]
            }
        }
    }

    /* Create RX buffer script */
    file { '/usr/local/sbin/rxbuffer':
        ensure  => file,
        source  => 'puppet:///modules/basic_settings/network/rxbuffer',
        owner   => 'root',
        group   => 'root',
        mode    => '0755', # High important
    }

    if (defined(Package['systemd'])) {
        /* Install package */
        package { 'networkd-dispatcher':
            ensure => installed,
            require => Package['ifupdown']
        }

        /* Set script that's set the firewall */
        if ($firewall_command != '') {
            file { 'firewall_networkd_dispatche':
                ensure  => file,
                path    => "/etc/networkd-dispatcher/routable.d/${firewall_package}",
                mode    => '0755',
                content => "#!/bin/bash\n\ntest -r /etc/firewall.conf && ${firewall_command}\n\nexit 0\n",
                require => Package[$firewall_package]
            }
        }

        /* Create RX buffer script */
        file { '/etc/networkd-dispatcher/routable.d/rxbuffer':
            ensure  => file,
            content  => template('basic_settings/network/rxbuffer'),
            owner   => 'root',
            group   => 'root',
            mode    => '0755', # High important,
            require => File['/usr/local/sbin/rxbuffer']
        }

        /* Ensure that networkd services is always running */
        service { ['systemd-networkd.service', 'networkd-dispatcher.service']:
            ensure      => running,
            enable      => true,
            require     => [Package['systemd'], Package['networkd-dispatcher']]
        }

        /* Create symlink to network service */
        if (defined(Package['dbus'])) {
            file { '/usr/lib/systemd/system/dbus-org.freedesktop.network1.service':
                ensure  => 'link',
                target  => '/usr/lib/systemd/system/systemd-networkd.service',
                notify  => Exec['network_firewall_systemd_daemon_reload'],
                require => Package['dbus']
            }
        }
    }
}
