class basic_settings::packages(
    $unattended_upgrades_block_extra_packages   = [],
    $unattended_upgrades_block_packages         = [
        'libmysql*',
        'mysql*',
        'nginx',
        'nodejs',
        'php*'
    ],
    $server_fdqn                                = $::networking['fqdn'],
    $snap_enable                                = false,
    $mail_to                                    = 'root'
) {
    /* Install apt package */
    if (!defined(Package['apt'])) {
        package { 'apt':
            ensure  => installed
        }
    }

    /* Install dpkg package */
    if (!defined(Package['dpkg'])) {
        package { 'dpkg':
            ensure  => installed
        }
    }

    /* Install package */
    package { ['apt-listchanges', 'apt-transport-https', 'ca-certificates', 'curl', 'debian-archive-keyring', 'debian-keyring', 'dirmngr', 'gnupg', 'libssl-dev', 'needrestart', 'ucf', 'unattended-upgrades']:
        ensure  => installed,
        require => Package['apt']
    }

    /* Set default rules */
    $default_rules = [
        '# Software manager',
        '-a always,exit -F arch=b32 -F path=/usr/bin/dpkg -F perm=x -F auid!=unset -F key=software_mgmt',
        '-a always,exit -F arch=b64 -F path=/usr/bin/dpkg -F perm=x -F auid!=unset -F key=software_mgmt',
        '-a always,exit -F arch=b32 -F path=/usr/bin/apt -F perm=x -F auid!=unset -F key=software_mgmt',
        '-a always,exit -F arch=b64 -F path=/usr/bin/apt -F perm=x -F auid!=unset -F key=software_mgmt',
        '-a always,exit -F arch=b32 -F path=/usr/bin/apt-get -F perm=x -F auid!=unset -F key=software_mgmt',
        '-a always,exit -F arch=b64 -F path=/usr/bin/apt-get -F perm=x -F auid!=unset -F key=software_mgmt'
    ]

    /* Check if we need snap */
    if (!$snap_enable) {
        /* Remove snap */
        $snap_rules = []
        package { 'snapd':
            ensure => purged
        }

        /* Remove unnecessary snapd and unminimize files */
        file { ['/etc/apt/apt.conf.d/20snapd.conf', '/etc/xdg/autostart/snap-userd-autostart.desktop']:
            ensure  => absent,
            require => Package['snapd']
        }
    } else {
        $snap_rules = [
            '-a always,exit -F arch=b32 -F path=/usr/bin/snap -F perm=x -F auid!=unset -F key=software_mgmt',
            '-a always,exit -F arch=b64 -F path=/usr/bin/snap -F perm=x -F auid!=unset -F key=software_mgmt',
            '-a always,exit -F arch=b32 -F path=/usr/bin/snapctl -F perm=x -F auid!=unset -F key=software_mgmt',
            '-a always,exit -F arch=b64 -F path=/usr/bin/snapctl -F perm=x -F auid!=unset -F key=software_mgmt',
        ]
        package { 'snapd':
            ensure => installed
        }
    }

    /* Remove unnecessary packages */
    package { 'packagekit':
        ensure => purged
    }

    /* Do extra steps when Ubuntu */
    if ($::os['name'] == 'Ubuntu') {
        /* Install extra packages when Ubuntu */
        package { 'update-manager-core':
            ensure => installed
        }

        /* Remove unnecessary snapd and unminimize files */
        file { ['/usr/local/sbin/unminimize', '/etc/update-motd.d/60-unminimize']:
            ensure => absent
        }

        /* Remove man */
        exec { 'packages_man_remove':
            command     => '/usr/bin/rm /usr/bin/man',
            onlyif      => ['[ -e /usr/bin/man ]', '[ -e /etc/dpkg/dpkg.cfg.d/excludes ]']
        }

        /* Create list of packages that is suspicious */
        $suspicious_packages =  ['/usr/bin/do-release-upgrade']

        /* Setup audit rules */
        if (defined(Package['auditd'])) {
            basic_settings::security_audit { 'packages':
                rules                       => flatten($default_rules, $snap_rules),
                rule_suspicious_packages    => $suspicious_packages
            }
        }
    } else {
        /* Create list of packages that is suspicious */
        $suspicious_packages =  []

        /* Setup audit rules */
        if (defined(Package['auditd'])) {
            basic_settings::security_audit { 'packages':
                rules => flatten($default_rules, $snap_rules)
            }
        }
    }

    /* Create unattended upgrades config  */
    $unattended_upgrades_block_all_packages = flatten($unattended_upgrades_block_extra_packages, $unattended_upgrades_block_packages);
    file { '/etc/apt/apt.conf.d/99-unattended-upgrades':
        ensure  => file,
        content  => template('basic_settings/packages/unattended-upgrades'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => Package['unattended-upgrades']
    }

    /* Create APT settings */
    file { '/etc/apt/apt.conf.d/99-settings':
        ensure  => file,
        content  => template('basic_settings/packages/settings'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => Package['unattended-upgrades']
    }

    /* Create needrestart config */
    file { '/etc/needrestart/conf.d/99-custom.conf':
        ensure  => file,
        content  => template('basic_settings/packages/needrestart.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => Package['needrestart']
    }

    /* Ensure that apt-daily timers is always running */
    service { ['apt-daily.timer', 'apt-daily-upgrade.timer']:
        ensure      => running,
        enable      => true,
        require     => Package['systemd']
    }

    if (defined(Package['systemd']) and defined(Class['basic_settings::message'])) {
        /* Reload systemd deamon */
        exec { 'packages_systemd_daemon_reload':
            command         => '/usr/bin/systemctl daemon-reload',
            refreshonly     => true,
            require         => Package['systemd']
        }

        /* Create drop in for APT service */
        basic_settings::systemd_drop_in { 'apt_daily_notify_failed':
            target_unit     => 'apt-daily.service',
            unit            => {
                'OnFailure' => 'notify-failed@%i.service'
            },
            daemon_reload   => 'packages_systemd_daemon_reload'
        }

        /* Create drop in for APT upgrade service */
        basic_settings::systemd_drop_in { 'apt_daily_upgrade_notify_failed':
            target_unit     => 'apt-daily-upgrade.service',
            unit            => {
                'OnFailure' => 'notify-failed@%i.service'
            },
            daemon_reload   => 'packages_systemd_daemon_reload'
        }
    }

    /* Check if logrotate package exists */
    if (defined(Package['logrotate'])) {
        /* Remove default file */
        basic_settings::io_logrotate { 'apt':
            path            => '',
            handle          => 'monthly',
            ensure          => absent
        }

        /* APT term */
        basic_settings::io_logrotate { 'apt_term':
            path            => '/var/log/apt/term.log',
            handle          => 'monthly'
        }

        /* APT history */
        basic_settings::io_logrotate { 'apt_history':
            path            => '/var/log/apt/history.log',
            handle          => 'monthly'
        }
    }
}
