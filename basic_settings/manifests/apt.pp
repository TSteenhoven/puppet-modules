class basic_settings::apt(
    $unattended_upgrades_block_extra_packages   = [],
    $unattended_upgrades_block_packages         = [
        'libmysql*',
        'mysql*',
        'nginx',
        'nodejs',
        'php*'
    ],
    $server_fdqn                                = $fqdn,
    $mail_to                                    = 'root'
) {

    /* Install package */
    package { ['apt-listchanges', 'apt-transport-https', 'debian-archive-keyring', 'debian-keyring', 'needrestart', 'unattended-upgrades']:
        ensure  => installed
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
        content  => template('basic_settings/needrestart.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['needrestart']
    }

    /* Ensure that apt-daily timers is always running */
    service { ['apt-daily.timer', 'apt-daily-upgrade.timer']:
        ensure      => running,
        enable      => true,
        require     => Package['unattended-upgrades']
    }
}
