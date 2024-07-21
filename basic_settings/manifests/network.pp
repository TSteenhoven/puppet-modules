class basic_settings::network(
    $firewall_package,
    $fallback_dns = [
        '8.8.8.8',
        '8.8.4.4',
        '2001:4860:4860::8888',
        '2001:4860:4860::8844'
    ],
    $firewall_path = '/etc/firewall.conf',
    $antivirus_package = undef,
    $install_options = undef
) {

    /* Default suspicious packages */
    $default_packages = ['/usr/bin/ip', '/usr/bin/mtr', '/usr/bin/nc', '/usr/bin/netcat', '/usr/bin/ping', '/usr/bin/ping4', '/usr/bin/ping6', '/usr/bin/tcptraceroute', '/usr/bin/telnet', '/usr/sbin/arp', '/usr/sbin/route', '/usr/sbin/traceroute']

    /* Based on firewall package do special commands */
    case $firewall_package {
        'nftables': {
            $firewall_command = ''
            package { ['iptables', 'firewalld']:
                ensure => purged
            }

            /* Create list of packages that is suspicious */
            $suspicious_packages = flatten($default_packages, ['/usr/sbin/nft'])
        }
        'iptables': {
            $firewall_command = "iptables-restore < ${firewall_path}"
            package { ['nftables', 'firewalld']:
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
                        '-a always,exclude -F exe=/opt/eset/efs/lib/odfeeder',
                        '-a always,exclude -F exe=/opt/eset/efs/lib/utild',
                    ],
                    order  => '01'
                }
            }
        }
    }

    /* Remove unnecessary packages */
    package { ['ifupdown', 'netcat-traditional', 'wpasupplicant']:
        ensure  => purged
    }

    /* Install package */
    package { ['dnsutils', 'ethtool', 'iputils-ping', 'mtr-tiny', 'netcat-openbsd', 'net-tools', 'telnet', 'iproute2', 'tcptraceroute', 'traceroute']:
        ensure => installed,
        require => Package['ifupdown']
    }

    /* If we need to install netplan */
    case $::os['name'] {
        'Ubuntu': {
            $netplan_rules = [
                '-a always,exit -F arch=b32 -F path=/etc/netplan -F perm=wa -F key=network',
                '-a always,exit -F arch=b64 -F path=/etc/netplan -F perm=wa -F key=network'
            ]
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
            command         => '/usr/bin/systemctl daemon-reload',
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
        $networkd_rules = [
            '-a always,exit -F arch=b32 -F path=/etc/networkd-dispatcher -F perm=wa -F key=network',
            '-a always,exit -F arch=b64 -F path=/etc/networkd-dispatcher -F perm=wa -F key=network'
        ]

        /* Install package */
        package { 'networkd-dispatcher':
            ensure => installed,
            require => Package['ifupdown']
        }

        /* Set script that's set the firewall */
        if ($firewall_command != '') {
            file { 'firewall_networkd_dispatcher':
                ensure  => file,
                path    => "/etc/networkd-dispatcher/routable.d/${firewall_package}",
                mode    => '0755',
                content => "#!/bin/bash\n\ntest -r ${firewall_path} && ${firewall_command}\n\nexit 0\n",
                require => Package[$firewall_package]
            }
        } else {
            /* Remove firewall package */
            case $firewall_package {
                'nftables', 'firewalld': {
                    file { 'firewall_networkd_dispatcher':
                        ensure  => absent,
                        path    => '/etc/networkd-dispatcher/routable.d/iptables',
                        require => Package[$firewall_package]
                    }
                }
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

        /* Check if systemd resolved package exists  */
        case $::os['name'] {
            'Ubuntu': {
                $os_version = $::os['release']['major']
                if ($os_version == '24.04') {
                    $systemd_resolved_package = true
                } else {
                    $systemd_resolved_package = false
                }
            }
            default: {
                $systemd_resolved_package = true
            }
        }

        /* Set settings */
        $systemd_resolved_settings = {
            'Cache'         => 'yes',
            'DNSOverTLS'    => 'opportunistic',
            'DNSSEC'        => 'allow-downgrade',
            'FallbackDNS'   => join($fallback_dns, ' '),
            'LLMNR'         => 'no',
            'MulticastDNS'  => 'no',
            'ReadEtcHosts'  => 'yes'
        }

        /* Check if we need to install a systemd resolved package or if it's all built-in */
        if ($systemd_resolved_package) {
            package { 'systemd-resolved':
                ensure          => installed,
                install_options => $install_options
            }

            /* Ensure that networkd services is always running */
            service { ['systemd-networkd.service', 'systemd-resolved.service', 'networkd-dispatcher.service']:
                ensure      => running,
                enable      => true,
                require     => [Package['systemd'], Package['systemd-resolved'], Package['networkd-dispatcher']]
            }

            /* Create drop in for systemd resolved service */
            basic_settings::systemd_drop_in { 'resolved_settings':
                target_unit     => 'resolved.conf',
                path            => '/etc/systemd',
                resolve         => $systemd_resolved_settings,
                daemon_reload   => 'network_firewall_systemd_daemon_reload',
                require         => Package['systemd-resolved']
            }
        } else {
            /* Ensure that networkd services is always running */
            service { ['systemd-networkd.service', 'systemd-resolved.service', 'networkd-dispatcher.service']:
                ensure      => running,
                enable      => true,
                require     => [Package['systemd'], Package['networkd-dispatcher']]
            }

            /* Create drop in for systemd resolved service */
            basic_settings::systemd_drop_in { 'resolved_settings':
                target_unit     => 'resolved.conf',
                path            => '/etc/systemd',
                resolve         => $systemd_resolved_settings,
                daemon_reload   => 'network_firewall_systemd_daemon_reload'
            }
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
        $suspicious_filter = delete($suspicious_packages, '/usr/bin/ip')
        basic_settings::security_audit { 'network':
            rules                       => flatten($netplan_rules, $networkd_rules),
            rule_suspicious_packages    => $suspicious_filter,
            order                       => 20
        }
        basic_settings::security_audit { 'network-root':
            rule_suspicious_packages    => delete($suspicious_packages, $suspicious_filter),
            rule_options                => ['-F auid!=unset'],
            order                       => 20
        }
    }
}
