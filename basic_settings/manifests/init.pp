class basic_settings(
        $cluster_id         = 'core',
        $backports          = false,
        $non_free           = false,
        $sury_enable        = false,
        $nginx_enable       = false,
        $proxmox_enable     = false,
        $mysql_enable       = false,
        $mysql_version      = '8.0',
        $nftables_enable    = true,
        $systemd_default_target = 'helpers'
    ) {

    /* Basic system packages */
    package { ['apt-transport-https', 'bc', 'ca-certificates', 'curl', 'debian-archive-keyring', 'debian-keyring', 'dirmngr', 'dnsutils', 'ethtool', 'gnupg', 'libssl-dev', 'lsb-release', 'mailutils', 'nano' ,'pwgen', 'python-is-python3', 'python3', 'rsync', 'ruby', 'screen', 'sudo', 'unzip', 'xz-utils']:
        ensure  => installed
    }

    /* Setup sudoers config file */
    file { '/etc/sudoers':
        ensure  => file,
        mode    => '0440',
        owner   => 'root',
        group   => 'root',
        content => template('basic_settings/sudoers')
    }

    /* Setip sudoers dir */
    file { '/etc/sudoers.d':
        ensure  => directory,
        purge   => true,
        recurse => true,
        force   => true,
    }

    /* Get debian name */
    if ($operatingsystemrelease =~ /^12.*/) {
        $backports_allow = false
        $sury_allow = true
        $nginx_allow = true
        $proxmox_allow = true
        $mysql_allow = true
        $debianname = 'bookworm'
        $mysql_debianname = 'bullseye'
    } else {
        $backports_allow = false
        $sury_allow = false
        $nginx_allow = false
        $proxmox_allow = false
        $mysql_allow = false
        $debianname = 'unknown'
        $mysql_debianname = $debianname
    }

    /* Based on debian name use correct source list */
    file { '/etc/apt/sources.list':
        ensure  => file,
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('basic_settings/source-firmware.list')
    }

    /* Reload source list */
    exec { 'source_list_reload':
        subscribe   => File['/etc/apt/sources.list'],
        command     => 'apt-get update',
        require     => File['/etc/apt/sources.list'],
        refreshonly => true
    }

    /* Check if we need backports */
    if ($backports and $backports_allow) {
        exec { 'source_backports':
            command     => "printf \"deb http://deb.debian.org/debian ${debianname}-backports main contrib\\n\" > /etc/apt/sources.list.d/${debianname}-backports.list; apt-get update;",
            unless      => "[ -e /etc/apt/sources.list.d/${debianname}-backports.list ]",
            require     => Exec['source_list_reload']
        }
    } else {
        exec { 'source_backports':
            command     => "rm /etc/apt/sources.list.d/${debianname}-backports.list; apt-get update;",
            onlyif      => "[ -e /etc/apt/sources.list.d/${debianname}-backports.list ]",
            require     => Exec['source_list_reload']
        }
    }

    /* Remove packages */
    if ($nftables_enable) {
        $firewall_package = 'nftables'
        $firewall_command = 'systemctl is-active --quiet nftables.service && nft --file /etc/firewall.conf'
        package { 'iptables':
            ensure => absent
        }
    } else {
        $firewall_package = 'iptables'
        $firewall_command = 'iptables-restore < /etc/firewall.conf'
        package { 'nftables':
            ensure => absent
        }
    }

    /* Install firewall and git */
    if ($backports and $allow_backports) {
        package { ['systemd', 'systemd-sysv', 'libpam-systemd', 'git', "${firewall_package}"]:
            ensure          => installed,
            install_options => ['-t', "${debianname}-backports"],
            require         => Exec['source_backports']
        }
    } else {
        package { ['systemd', 'systemd-sysv', 'libpam-systemd', 'git', "${firewall_package}"]:
            ensure  => installed,
            require => Exec['source_backports']
        }
    }

    /* Systemd storage target */
    basic_settings::systemd_target { "${cluster_id}-system":
        description     => 'System',
        parent_targets  => ['multi-user'],
        allow_isolate   => true
    }

    /* Systemd storage target */
    basic_settings::systemd_target { "${cluster_id}-storage":
        description     => 'Storage',
        parent_targets  => ["${cluster_id}-system"],
        allow_isolate   => true
    }

    /* Systemd services target */
    basic_settings::systemd_target { "${cluster_id}-services":
        description     => 'Services',
        parent_targets  => ["${cluster_id}-storage"],
        allow_isolate   => true
    }

    /* Systemd production target */
    basic_settings::systemd_target { "${cluster_id}-production":
        description     => 'Production',
        parent_targets  => ["${cluster_id}-services"],
        allow_isolate   => true
    }

    /* Systemd helpers target */
    basic_settings::systemd_target { "${cluster_id}-helpers":
        description     => 'Helpers',
        parent_targets  => ["${cluster_id}-production"],
        allow_isolate   => true
    }

    /* Systemd require services target */
    basic_settings::systemd_target { "${cluster_id}-require-services":
        description     => 'Require services',
        parent_targets  => ["${cluster_id}-helpers"],
        allow_isolate   => true
    }

    /* Set default target */
    exec { 'set_default_target':
        command => "systemctl set-default ${cluster_id}-${systemd_default_target}.target",
        unless  => "test `/bin/systemctl get-default` = '${cluster_id}-${systemd_default_target}.target'",
        require => [Package['systemd'], File["/etc/systemd/system/${cluster_id}-${systemd_default_target}.target"]]
    }

    /* Reload systemd deamon */
    exec { 'systemd_daemon_reload':
        command => 'systemctl daemon-reload',
        refreshonly => true,
        require => Package['systemd']
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
    file { 'firewall_if_pre_up':
        ensure  => file,
        path    => "/etc/network/if-pre-up.d/${firewall_package}",
        mode    => '0755',
        content => "#!/bin/bash\n\ntest -r /etc/firewall.conf && ${firewall_command}\n\nexit 0\n",
        require => Package["${firewall_package}"]
    }

    /* Create RX buffer script */
    file { '/etc/network/rxbuffer.sh':
        ensure  => file,
        source  => 'puppet:///modules/basic_settings/rxbuffer.sh',
        owner   => 'root',
        group   => 'root',
        mode    => '0755', # High important
    }

    /* Check if we need sury */
    if ($sury_enable and $sury_allow) {
        /* Add sury PHP repo */
        exec { 'source_sury_php':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ ${debianname} main\\n\" > /etc/apt/sources.list.d/sury_php.list; curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg; apt-get update;",
            unless      => '[ -e /etc/apt/sources.list.d/sury_php.list ]',
            require     => [Package['curl'], Package['gnupg']]
        }
    } else {
        /* Remove sury php repo */
        exec { 'source_sury_php':
            command     => 'rm /etc/apt/sources.list.d/sury_php.list; apt-get update;',
            onlyif      => '[ -e /etc/apt/sources.list.d/sury_php.list ]',
            require     => Exec['source_list_reload']
        }
    }

    /* Check if variable nginx is true; if true, install new source list and key */
    if ($nginx_enable and $nginx_allow) {
        exec { 'source_nginx':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian ${debianname} nginx\\n\" > /etc/apt/sources.list.d/nginx.list; curl -s https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null; apt-get update;",
            unless      => '[ -e /etc/apt/sources.list.d/nginx.list ]',
            require     => [Package['curl'], Package['gnupg']]
        }
    } else {
        /* Remove nginx repo */
        exec { 'source_nginx':
            command     => 'rm /etc/apt/sources.list.d/nginx.list; apt-get update;',
            onlyif      => '[ -e /etc/apt/sources.list.d/nginx.list ]',
            require     => Exec['source_list_reload']
        }
    }

    /* Check if variable proxmox is true; if true, install new source list and key */
    if ($proxmox_enable and $proxmox_allow) {
        exec { 'source_proxmox':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/proxmox-release-bookworm.gpg] http://download.proxmox.com/debian/pve ${debianname} pve-no-subscription\\n\" > /etc/apt/sources.list.d/pve-install-repo.list; curl -sSLo /usr/share/keyrings/proxmox-release-bookworm.gpg https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg; apt-get update;",
            unless      => '[ -e /etc/apt/sources.list.d/pve-install-repo.list.list ]',
            require     => [Package['curl'], Package['gnupg']]
        }
    } else {
        /* Remove proxmox repo */
        exec { 'source_proxmox':
            command     => 'rm /etc/apt/sources.list.d/pve-install-repo.list.list; apt-get update;',
            onlyif      => '[ -e /etc/apt/sources.list.d/pve-install-repo.list.list ]',
            require     => Exec['source_list_reload']
        }
    }

    /* Check if variable mysql is true; if true, install new source list and key */
    if ($mysql_enable and $mysql_allow) {
        /* Get source name */
        case $mysql_version {
            '8.0': {
                $mysql_key = 'mysql-8.key'
            }
            default: {
                $mysql_key = 'mysql-7.key'
            }
        }

        /* Create MySQL key */
        file { 'source_mysql_key':
            ensure  => file,
            path    => '/usr/share/keyrings/mysql.key',
            source  => "puppet:///modules/basic_settings/mysql/${mysql_key}",
            owner   => 'root',
            group   => 'root',
            mode    => '0644'
        }

        /* Set source */
        exec { 'source_mysql':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/mysql.gpg] http://repo.mysql.com/apt/debian ${mysql_debianname} mysql-${mysql_version}\\n\" > /etc/apt/sources.list.d/mysql.list; cat /usr/share/keyrings/mysql.key | gpg --dearmor | sudo tee /usr/share/keyrings/mysql.gpg >/dev/null; apt-get update;",
            unless      => '[ -e /etc/apt/sources.list.d/mysql.list ]',
            require     => [Package['curl'], Package['gnupg']]
        }
    } else {
        /* Remove mysql repo */
        exec { 'source_mysql':
            command     => 'rm /etc/apt/sources.list.d/mysql.list; apt-get update;',
            onlyif      => '[ -e /etc/apt/sources.list.d/mysql.list ]',
            require     => Exec['source_list_reload']
        }
    }

    /* Disable service */
    service { 'puppet':
        ensure  => true,
        enable  => false
    }

    /* Create drop in for services target */
    basic_settings::systemd_drop_in { 'puppet_dependency':
        target_unit     => "${basic_settings::cluster_id}-system.target",
        unit            => {
            'Wants'   => 'puppet.service'
        },
        require         => Basic_settings::Systemd_target["${basic_settings::cluster_id}-system"]
    }

    /* Create drop in for puppet service */
    basic_settings::systemd_drop_in { 'puppet_settings':
        target_unit     => 'puppet.service',
        service         => {
            'Nice'          => 19,
            'LimitNOFILE'   => 10000
        }
    }
}
