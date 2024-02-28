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

    /* Install package */
    package { 'networkd-dispatcher':
        ensure => installed
    }

    /* Start nftables */
    if ($firewall_package == 'nftables') {
        service { "${firewall_package}":
            ensure      => running,
            enable      => true,
            require     => Package["${firewall_package}"]
        }
    }

    /* Set script that's set the firewall */
    if ($firewall_command != '') {
        file { 'firewall_networkd_dispatche':
            ensure  => file,
            path    => "/etc/networkd-dispatcher/routable.d/${firewall_package}",
            mode    => '0755',
            content => "#!/bin/bash\n\ntest -r /etc/firewall.conf && ${firewall_command}\n\nexit 0\n",
            require => Package["${firewall_package}"]
        }
    }

    /* Create RX buffer script */
    file { '/usr/local/sbin/rxbuffer':
        ensure  => file,
        source  => 'puppet:///modules/basic_settings/rxbuffer',
        owner   => 'root',
        group   => 'root',
        mode    => '0755', # High important
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
}
