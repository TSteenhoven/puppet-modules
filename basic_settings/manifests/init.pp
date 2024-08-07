class basic_settings(
        $adwaita_icon_theme_enable                  = false,
        $antivirus_package                          = undef,
        $backports                                  = false,
        $cluster_id                                 = 'core',
        $dconf_service_enable                       = false,
        $docs_enable                                = false,
        $firewall_package                           = 'nftables',
        $getty_enable                               = false,
        $guest_agent_enable                         = false,
        $kernel_connection_max                      = 4096,
        $kernel_hugepages                           = 0,
        $kernel_network_mode                        = 'strict',
        $kernel_security_lockdown                   = 'integrity',
        $kernel_tcp_congestion_control              = 'brr',
        $kernel_tcp_fastopen                        = 3,
        $locale_enable                              = false,
        $mail_package                               = 'postfix',
        $mongodb_enable                             = false,
        $mongodb_version                            = '4.4',
        $mysql_enable                               = false,
        $mysql_version                              = '8.0',
        $nginx_enable                               = false,
        $nodejs_enable                              = false,
        $nodejs_version                             = '20',
        $non_free                                   = false,
        $openjdk_enable                             = false,
        $openjdk_version                            = 'default',
        $pro_enable                                 = false,
        $proxmox_enable                             = false,
        $puppetserver_enable                        = false,
        $rabbitmq_enable                            = false,
        $server_fdqn                                = $::networking['fqdn'],
        $server_timezone                            = 'UTC',
        $smtp_server                                = 'localhost',
        $snap_enable                                = false,
        $sudoers_dir_enable                         = true,
        $sury_enable                                = false,
        $systemd_default_target                     = 'helpers',
        $systemd_notify_mail                        = 'root',
        $systemd_ntp_extra_pools                    = [],
        $unattended_upgrades_block_extra_packages   = [],
        $unattended_upgrades_block_packages         = [
            'libmysql*',
            'mysql*',
            'nginx',
            'nodejs',
            'php*',
            'rabbitmq-server'
        ]
    ) {

    /* Get OS name */
    case $::os['name'] {
        'Ubuntu': {
            /* Set some variables */
            $os_parent = 'ubuntu'
            $os_repo = 'main universe restricted'
            if ($::os['architecture'] == 'amd64') {
                $os_url = 'http://archive.ubuntu.com/ubuntu/'
                $os_url_security = 'http://security.ubuntu.com/ubuntu'
            } else {
                $os_url = 'http://ports.ubuntu.com/ubuntu-ports/'
                $os_url_security = 'http://ports.ubuntu.com/ubuntu-ports/'
            }

            /* Do thing based on version */
            if ($::os['release']['major'] == '24.04') { # LTS
                $backports_allow = false
                $deb_version = '822'
                $gcc_version = undef
                $mongodb_allow = true
                if ($::os['architecture'] == 'amd64') {
                    $mysql_allow = true
                } else {
                    $mysql_allow = false
                }
                $nginx_allow = true
                $nodejs_allow = true
                $openjdk_allow = true
                $os_name = 'noble'
                $rabbitmq_allow = true
                $proxmox_allow = false
                $puppetserver_dir = 'puppetserver'
                $puppetserver_jdk = true
                $puppetserver_package = 'puppetserver'
                $sury_allow = false
            } elsif ($::os['release']['major'] == '23.04') { # Stable
                $backports_allow = false
                $deb_version = 'list'
                $gcc_version = 12
                $mongodb_allow = true
                if ($::os['architecture'] == 'amd64') {
                    $mysql_allow = true
                } else {
                    $mysql_allow = false
                }
                $nginx_allow = true
                $nodejs_allow = true
                $openjdk_allow = true
                $os_name = 'lunar'
                $rabbitmq_allow = true
                $proxmox_allow = false
                $puppetserver_dir = 'puppetserver'
                $puppetserver_jdk = true
                $puppetserver_package = 'puppetserver'
                $sury_allow = false
            } elsif ($::os['release']['major'] == '22.04') { # LTS
                $backports_allow = false
                $deb_version = 'list'
                $gcc_version = 12
                $mongodb_allow = true
                if ($::os['architecture'] == 'amd64') {
                    $mysql_allow = true
                } else {
                    $mysql_allow = false
                }
                $nginx_allow = true
                $nodejs_allow = true
                $openjdk_allow = true
                $os_name = 'jammy'
                $rabbitmq_allow = true
                $proxmox_allow = false
                $puppetserver_dir = 'puppet'
                $puppetserver_jdk = false
                $puppetserver_package = 'puppet-master'
                $sury_allow = true
            } else {
                $backports_allow = false
                $deb_version = 'list'
                $gcc_version = undef
                $mongodb_allow = false
                $mysql_allow = false
                $nginx_allow = false
                $nodejs_allow = false
                $openjdk_allow = false
                $os_name = 'unknown'
                $rabbitmq_allow = false
                $proxmox_allow = false
                $puppetserver_dir = 'puppet'
                $puppetserver_jdk = false
                $puppetserver_package = 'puppet-master'
                $sury_allow = false
            }
        }
        'Debian': {
            /* Set some variables */
            $os_parent = 'debian'
            $os_repo = 'main contrib non-free-firmware'
            $os_url = 'http://deb.debian.org/debian/'
            $os_url_security = 'http://deb.debian.org/debian-security/'

            /* Do thing based on version */
            if ($::os['release']['major'] == '12') {
                $backports_allow = false
                $deb_version = 'list'
                $gcc_version = undef
                $mongodb_allow = true
                if ($::os['architecture'] == 'amd64') {
                    $mysql_allow = true
                } else {
                    $mysql_allow = false
                }
                $nginx_allow = true
                $nodejs_allow = true
                $openjdk_allow = true
                $os_name = 'bookworm'
                $rabbitmq_allow = true
                $proxmox_allow = false
                $puppetserver_dir = 'puppetserver'
                $puppetserver_jdk = true
                $puppetserver_package = 'puppetserver'
                $sury_allow = true
            } else {
                $backports_allow = false
                $deb_version = 'list'
                $gcc_version = undef
                $mongodb_allow = false
                $mysql_allow = false
                $nginx_allow = false
                $nodejs_allow = false
                $openjdk_allow = false
                $os_name = 'unknown'
                $rabbitmq_allow = false
                $proxmox_allow = false
                $puppetserver_dir = 'puppet'
                $puppetserver_jdk = false
                $puppetserver_package = 'puppet-master'
                $sury_allow = false
            }
        }
        default: {
            $backports_allow = false
            $deb_version = 'list'
            $gcc_version = undef
            $mongodb_allow = false
            $mysql_allow = false
            $nginx_allow = false
            $nodejs_allow = false
            $openjdk_allow = false
            $os_name = 'unknown'
            $rabbitmq_allow = false
            $proxmox_allow = false
            $puppetserver_dir = 'puppet'
            $puppetserver_jdk = false
            $puppetserver_package = 'puppet-master'
            $sury_allow = false
        }
    }

    /* Get snap state */
    if ($pro_enable and !$snap_enable) {
        $snap_correct = true
    } else {
        $snap_correct = $snap_enable
    }

    /* Basic system packages; This packages needed to be installed first */
    package { ['apt', 'bc', 'coreutils', 'grep', 'lsb-release', 'sed', 'util-linux']:
        ensure  => installed
    }

    /* Remove unnecessary packages */
    package { ['at-spi2-core', 'lxd-installer', 'plymouth', 'x11-utils']:
        ensure  => purged
    }

    /* Basic system packages */
    package { ['sysstat']:
        ensure  => installed
    }

    /* Reload source list */
    exec { 'basic_settings_source_reload':
        command     => 'apt-get update',
        refreshonly => true
    }

    /* Check if we need newer format for APT */
    if ($deb_version == '822') {
        /* Based on OS parent use correct source list */
        file { '/etc/apt/sources.list':
            path    => '/etc/apt/sources.list',
            ensure  => file,
            mode    => '0644',
            owner   => 'root',
            group   => 'root',
            content => "# ${::os['name']} sourcess have to moved to /etc/apt/sources.list.d/${os_parent}.sources\n",
            require => Package['apt']
        }

        /* Based on OS parent use correct source list */
        file { 'basic_settings_source':
            path    => "/etc/apt/sources.list.d/${os_parent}.sources",
            ensure  => file,
            mode    => '0644',
            owner   => 'root',
            group   => 'root',
            content => template("basic_settings/source/${os_parent}.sources"),
            require => [Package['apt'], File['/etc/apt/sources.list']]
        }

        /* Check if we need backports */
        if ($backports and $backports_allow) {
            $backports_install_options = ['-t', "${os_name}-backports"]
        } else {
            $backports_install_options = undef
        }
    } else {
        /* Check if we need backports */
        if ($backports and $backports_allow) {
            $backports_install_options = ['-t', "${os_name}-backports"]
            exec { 'basic_settings_source_backports':
                command     => "/usr/bin/printf \"deb ${os_url} ${os_name}-backports ${os_repo}\\n\" > /etc/apt/sources.list.d/${os_name}-backports.list",
                unless      => "[ -e /etc/apt/sources.list.d/${os_name}-backports.list ]",
                notify      => Exec['basic_settings_source_reload'],
                require     => [Package['apt'], Package['coreutils']]
            }
        } else {
            $backports_install_options = undef
            exec { 'basic_settings_source_backports':
                command     => "/usr/bin/rm /etc/apt/sources.list.d/${os_name}-backports.list",
                onlyif      => "[ -e /etc/apt/sources.list.d/${os_name}-backports.list ]",
                notify      => Exec['basic_settings_source_reload'],
                require     => [Package['apt'], Package['coreutils']]
            }
        }

        /* Based on OS parent use correct source list */
        file { 'basic_settings_source':
            path    => '/etc/apt/sources.list',
            ensure  => file,
            mode    => '0644',
            owner   => 'root',
            group   => 'root',
            content => template("basic_settings/source/${os_parent}.list"),
            require => Exec['basic_settings_source_backports']
        }
    }

    /* Set systemd */
    class { 'basic_settings::systemd':
        cluster_id      => $cluster_id,
        default_target  => $systemd_default_target,
        install_options => $backports_install_options,
        require         => File['basic_settings_source']
    }

    /* Setup message */
    class { 'basic_settings::message':
        mail_to         => $systemd_notify_mail,
        mail_package    => $mail_package,
        server_fdqn     => $server_fdqn,
        require         => Class['basic_settings::systemd']
    }

    /* Setup security */
    class { 'basic_settings::security':
        mail_to         => $systemd_notify_mail,
        server_fdqn     => $server_fdqn,
        require         => Class['basic_settings::message']
    }

    /* Setup APT */
    class { 'basic_settings::packages':
        unattended_upgrades_block_extra_packages   => $unattended_upgrades_block_extra_packages,
        unattended_upgrades_block_packages         => $unattended_upgrades_block_packages,
        server_fdqn                                => $server_fdqn,
        snap_enable                                => $snap_correct,
        mail_to                                    => $systemd_notify_mail,
        require                                    => [File['/etc/apt/sources.list'], Class['basic_settings::message']]
    }

    /* Set Pro */
    class { 'basic_settings::pro':
        enable  => $pro_enable,
        require => Class['basic_settings::message']
    }

    /* Set timezone */
    class { 'basic_settings::timezone':
        timezone        => $server_timezone,
        ntp_extra_pools => $systemd_ntp_extra_pools,
        install_options => $backports_install_options,
        require         => [File['basic_settings_source'], Class['basic_settings::message']]
    }

    /* Setup kernel */
    class { 'basic_settings::kernel':
        antivirus_package       => $antivirus_package,
        connection_max          => $kernel_connection_max,
        guest_agent_enable      => $guest_agent_enable,
        hugepages               => $kernel_hugepages,
        install_options         => $backports_install_options,
        network_mode            => $kernel_network_mode,
        security_lockdown       => $kernel_security_lockdown,
        tcp_congestion_control  => $kernel_tcp_congestion_control,
        tcp_fastopen            => $kernel_tcp_fastopen
    }

    /* Set network */
    class { 'basic_settings::network':
        antivirus_package   => $antivirus_package,
        firewall_package    => $firewall_package,
        install_options     => $backports_install_options,
        require             => [File['basic_settings_source'], Class['basic_settings::message']]
    }

    /* Set timezone */
    class { 'basic_settings::locale':
        enable              => $locale_enable,
        docs_enable         => $docs_enable
    }

    /* Set IO */
    class { 'basic_settings::io':
    }

    /* Check if variable rabbitmq is true; if true, install new source list and key */
    if ($sury_enable and $sury_allow) {
        class { 'basic_settings::package_sury':
            deb_version => $deb_version,
            enable      => true,
            os_parent   => $os_parent,
            os_name     => $os_name,
            require     => Class['basic_settings::packages']
        }
    } else {
        class { 'basic_settings::package_sury':
            deb_version => $deb_version,
            enable      => false,
            os_parent   => $os_parent,
            os_name     => $os_name
        }
    }

    /* Check if variable nginx is true; if true, install new source list and key */
    if ($nginx_enable and $nginx_allow) {
        class { 'basic_settings::package_nginx':
            deb_version => $deb_version,
            enable      => true,
            os_parent   => $os_parent,
            os_name     => $os_name,
            require     => Class['basic_settings::packages']
        }
    } else {
        class { 'basic_settings::package_nginx':
            deb_version => $deb_version,
            enable      => false,
            os_parent   => $os_parent,
            os_name     => $os_name
        }
    }

    /* Check if variable rabbitmq is true; if true, install new source list and key */
    if ($rabbitmq_enable and $rabbitmq_allow) {
        class { 'basic_settings::package_rabbitmq':
            deb_version => $deb_version,
            enable      => true,
            os_parent   => $os_parent,
            os_name     => $os_name,
            require     => Class['basic_settings::packages']
        }
    } else {
        class { 'basic_settings::package_rabbitmq':
            deb_version => $deb_version,
            enable      => false,
            os_parent   => $os_parent,
            os_name     => $os_name
        }
    }

    /* Check if variable proxmox is true; if true, install new source list and key */
    if ($proxmox_enable and $proxmox_allow) {
        class { 'basic_settings::package_proxmox':
            deb_version => $deb_version,
            enable      => true,
            os_parent   => $os_parent,
            os_name     => $os_name,
            require     => Class['basic_settings::packages']
        }
    } else {
        class { 'basic_settings::package_proxmox':
            deb_version => $deb_version,
            enable      => false,
            os_parent   => $os_parent,
            os_name     => $os_name
        }
    }

    /* Check if variable mysql is true; if true, install new source list and key */
    if ($mysql_enable and $mysql_allow) {
        class { 'basic_settings::package_mysql':
            deb_version => $deb_version,
            enable      => true,
            os_parent   => $os_parent,
            os_name     => $os_name,
            version     => $mysql_version,
            require     => Class['basic_settings::packages']
        }
    } else {
        class { 'basic_settings::package_mysql':
            deb_version => $deb_version,
            enable      => false,
            os_parent   => $os_parent,
            os_name     => $os_name
        }
    }

    /* Check if variable mysql is true; if true, install new source list and key */
    if ($mongodb_enable and $mongodb_allow) {
        class { 'basic_settings::package_mongodb':
            deb_version => $deb_version,
            enable      => true,
            os_parent   => $os_parent,
            os_name     => $os_name,
            version     => $mongodb_version,
            require     => Class['basic_settings::packages']
        }
    } else {
        class { 'basic_settings::package_mongodb':
            deb_version => $deb_version,
            enable      => false,
            os_parent   => $os_parent,
            os_name     => $os_name
        }
    }

    /* Check if variable nodejs is true; if true, install new source list and key */
    if ($nodejs_enable and $nodejs_allow) {
        class { 'basic_settings::package_node':
            enable      => true,
            version     => $nodejs_version,
            require     => Class['basic_settings::packages']
        }
    } else {
        class { 'basic_settings::package_node':
            enable      => false,
            require     => Class['basic_settings::packages']
        }
    }

    /* Check if variable openjdk is true; if true, install new package */
    if (($puppetserver_enable and $puppetserver_jdk) or ($openjdk_enable and $openjdk_allow)) {
        /* Get package name */
        if ($puppetserver_enable or $openjdk_version == 'default') {
            $openjdk_package = 'default-jdk'
        } else {
            $openjdk_package = "openjdk-${openjdk_version}-jdk"
        }

        /* Install openjdk package */
        package { 'openjdk':
            name    => $openjdk_package,
            ensure  => installed
        }

        /* Install java extensions */
        package { [ 'adwaita-icon-theme', 'ca-certificates-java', 'dconf-service']:
            ensure  => installed,
            require => Package['openjdk']
        }
    } else {
        /* Remove openjdk package */
        package { 'openjdk':
            name    => 'openjdk*',
            ensure  => purged
        }

        /* Check if we need to install adwaita theme */
        if ($adwaita_icon_theme_enable) {
            package { 'adwaita-icon-theme':
                ensure  => installed,
                require => Package['openjdk']
            }
        } else {
            package { 'adwaita-icon-theme':
                ensure  => purged,
                require => Package['openjdk']
            }
        }

        /* Check if we need to install dconf-service */
        if ($dconf_service_enable) {
            package { 'dconf-service':
                ensure  => installed,
                require => Package['openjdk']
            }
        } else {
            package { 'dconf-service':
                ensure  => purged,
                require => Package['openjdk']
            }
        }

        /* Remove java extensions */
        package { ['ca-certificates-java']:
            ensure  => purged,
            require => Package['openjdk']
        }
    }

    /* Setup development */
    class { 'basic_settings::development':
        gcc_version     => $gcc_version,
        install_options => $backports_install_options,
        require         => File['basic_settings_source']
    }

    /* Setup Puppet */
    class { 'basic_settings::puppet':
        server_enable  => $puppetserver_enable,
        server_package => $puppetserver_package,
        server_dir     => $puppetserver_dir
    }

    /* Setup login */
    class { 'basic_settings::login':
        getty_enable        => $getty_enable,
        mail_to             => $systemd_notify_mail,
        server_fdqn         => $server_fdqn,
        sudoers_dir_enable  => $sudoers_dir_enable
    }
}
