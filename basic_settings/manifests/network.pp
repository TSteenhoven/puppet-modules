class basic_settings::network(
    $firewall_package,
    $antivirus_package = undef,
    $install_options = undef,
) {

    /* Default suspicious packages */
    $default_packages = ['/usr/bin/ip', '/usr/bin/mtr', '/usr/bin/nc', '/usr/bin/netcat', '/usr/bin/ping', '/usr/bin/ping4', '/usr/bin/ping6', '/usr/bin/tcptraceroute', '/usr/bin/telnet', '/usr/sbin/arp', '/usr/sbin/route', '/usr/sbin/traceroute']

    /* Based on firewall package do special commands */
    case $firewall_package {
        'nftables': {
            $firewall_command = 'systemctl is-active --quiet nftables.service && nft --file /etc/firewall.conf'
            package { ['iptables', 'firwalld']:
                ensure => purged
            }

            /* Create list of packages that is suspicious */
            $suspicious_packages = flatten($default_packages, ['/usr/sbin/nft'])
        }
        'iptables': {
            $firewall_command = 'iptables-restore < /etc/firewall.conf'
            package { ['nftables', 'firwalld']:
                ensure => purged
            }

            /* Create list of packages that is suspicious */
            $suspicious_packages = flatten($default_packages, ['/usr/sbin/iptables'])
        }
        'firewalld': {
            $firewall_command = ''
            case $antivirus_package {
                'eset': {
                    package { 'iptables':
                        ensure => purged
                    }
                    package { 'nftables':
                        ensure  => installed
                    }

                    /* Create list of packages that is suspicious */
                    $suspicious_packages = flatten($default_packages, ['/usr/bin/firewall-cmd', '/usr/sbin/nft'])
                }
                default:  {
                    package { ['nftables', 'iptables']:
                        ensure => purged
                    }

                    /* Create list of packages that is suspicious */
                    $suspicious_packages = flatten($default_packages, ['/usr/bin/firewall-cmd'])
                }
            }
        }
    }

    /* Install package */
    package { "${firewall_package}":
        ensure          => installed,
        install_options => $install_options
    }

    /* Setup audit rules */
    if (defined(Package['auditd'])) {
        case $antivirus_package {
            'eset': {
                basic_settings::security_audit { 'eset':
                    rules  => [
                        '-a never,exclude -F exe=/opt/eset/efs/lib/odfeeder',
                        '-a never,exclude -F exe=/opt/eset/efs/lib/utild',
                    ],
                    order  => '01'
                }
            }
        }
    }

    /* Remove unnecessary packages */
    package { ['ifupdown', 'wpasupplicant']:
        ensure  => purged
    }

    /* Install package */
    package { ['dnsutils', 'ethtool', 'iputils-ping', 'mtr-tiny', 'netcat', 'net-tools', 'telnet', 'iproute2', 'tcptraceroute', 'traceroute']:
        ensure => installed,
        require => Package['ifupdown']
    }

    /* If we need to install netplan */
    case $operatingsystem {
        'Ubuntu': {
            $netplan_rules = [' -w /etc/netplan -p wa -k network']
            package { 'netplan.io':
                ensure  => installed
            }
        }
        default: {
            $netplan_rules = []
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

        if (defined(Package['systemd']) and defined(Class['basic_settings::message'])) {
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
        /* Set networkd rules */
        $networkd_rules = ['-w /etc/networkd-dispatcher -p wa -k network']

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
    } else {
        $networkd_rules = []
    }

    /* Setup audit rules */
    if (defined(Package['auditd'])) {
        basic_settings::security_audit { 'network':
            rules                       => flatten($netplan_rules, $networkd_rules),
            rule_suspicious_packages    => $suspicious_packages,
            order                       => 20
        }
    }
}
