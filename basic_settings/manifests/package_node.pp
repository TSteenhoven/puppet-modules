class basic_settings::package_node(
    $enable,
    $version = '20'
) {
    /* Reload source list */
    exec { 'package_node_source_list_reload':
        command     => 'apt-get update',
        refreshonly => true
    }

    if ($enable) {
        /* Install source list */
        exec { 'source_nodejs':
            command     => "curl -fsSL https://deb.nodesource.com/setup_${version}.x | bash - &&\\",
            unless      => '[ -e /etc/apt/sources.list.d/nodesource.list ]',
            notify      => Exec['package_node_source_list_reload'],
            require     => Package['curl']
        }

        /* Install nodejs package */
        package { 'nodejs':
            ensure  => installed,
            require => Exec['source_nodejs']
        }

        /* Create list of packages that is suspicious */
        $suspicious_packages = ['/usr/local/npm']

        /* Setup audit rules */
        if (defined(Package['auditd'])) {
            basic_settings::security_audit { 'node':
                rule_suspicious_packages => $suspicious_packages
            }
        }
    } else {
        /* Remove nodejs package */
        package { 'nodejs':
            ensure  => purged
        }

        /* Remove nodejs repo */
        exec { 'source_nodejs':
            command     => '/usr/bin/rm /etc/apt/sources.list.d/nodesource.list',
            onlyif      => '[ -e /etc/apt/sources.list.d/nodesource.list ]',
            notify      => Exec['package_node_source_list_reload'],
            require     => Package['nodejs']
        }
    }
}
