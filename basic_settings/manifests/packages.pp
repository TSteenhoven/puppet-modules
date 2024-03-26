class basic_settings::packages(
    $unattended_upgrades_block_extra_packages   = [],
    $unattended_upgrades_block_packages         = [
        'libmysql*',
        'mysql*',
        'nginx',
        'nodejs',
        'php*'
    ],
    $server_fdqn                                = $fqdn,
    $snap_enable                                = false,
    $mail_to                                    = 'root'
) {

    /* Install package */
    package { ['apt-listchanges', 'apt-transport-https', 'debian-archive-keyring', 'debian-keyring', 'dirmngr', 'ca-certificates', 'curl', 'gnupg', 'needrestart', 'unattended-upgrades']:
        ensure  => installed
    }

    /* Check if we need snap */
    if (!$snap_enable) {
        /* Remove snap */
        package { 'snapd':
            ensure => purged
        }

        /* Remove unnecessary snapd and unminimize files */
        file { ['/etc/apt/apt.conf.d/20snapd.conf', '/etc/xdg/autostart/snap-userd-autostart.desktop']:
            ensure  => absent,
            require => Package['snapd']
        }
    } else {
        package { 'snapd':
            ensure => installed
        }
    }

    /* Remove unnecessary packages */
    package { 'packagekit':
        ensure => purged
    }

    /* Do extra steps when Ubuntu */
    if ($operatingsystem == 'Ubuntu') {
        /* Install extra packages when Ubuntu */
        package { 'update-manager-core':
            ensure => installed
        }

        /* Remove unnecessary snapd and unminimize files */
        file { ['/usr/local/sbin/unminimize', '/etc/update-motd.d/60-unminimize']:
            ensure      => absent
        }

        /* Remove man */
        exec { 'packages_man_remove':
            command     => 'rm /usr/bin/man',
            onlyif      => ['[ -e /usr/bin/man ]', '[ -e /etc/dpkg/dpkg.cfg.d/excludes ]']
        }
    }

    /* Create unattended upgrades config  */
    $unattended_upgrades_block_all_packages = flatten($unattended_upgrades_block_extra_packages, $unattended_upgrades_block_packages);
    file { '/etc/apt/apt.conf.d/99-unattended-upgrades':
        ensure  => file,
        content  => template('basic_settings/apt/unattended-upgrades'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['unattended-upgrades']
    }

    /* Create APT settings */
    file { '/etc/apt/apt.conf.d/99-settings':
        ensure  => file,
        content  => template('basic_settings/apt/settings'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['unattended-upgrades']
    }

    /* Create needrestart config */
    file { '/etc/needrestart/conf.d/99-custom.conf':
        ensure  => file,
        content  => template('basic_settings/apt/needrestart.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
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
            command         => 'systemctl daemon-reload',
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
}
