class basic_settings(
        $backports                                  = false,
        $cluster_id                                 = 'core',
        $firewall_package                           = 'nftables',
        $kernel_hugepages                           = 0,
        $kernel_tcp_congestion_control              = 'brr',
        $kernel_tcp_fastopen                        = 3,
        $mail_package                               = 'postfix',
        $mongodb_enable                             = false,
        $mongodb_version                            = '4.4',
        $mysql_enable                               = false,
        $mysql_version                              = '8.0',
        $nginx_enable                               = false,
        $nodejs_enable                              = false,
        $nodejsx_version                             = '20',
        $non_free                                   = false,
        $openjdk_enable                             = false,
        $openjdk_version                            = 'default',
        $proxmox_enable                             = false,
        $puppetserver_enable                        = false,
        $server_fdqn                                = $fqdn,
        $server_timezone                            = 'UTC',
        $smtp_server                                = 'localhost',
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
            'php*'
        ]
    ) {

    /* Remove unnecessary packages */
    package { ['apport', 'at-spi2-core', 'chrony', 'cloud-init', 'installation-report', 'lxd-installer', 'packagekit', 'session-migration', 'snapd', 'xdg-user-dirs', 'x11-utils']:
        ensure  => purged
    }

    /* Basic system packages */
    package { ['bash-completion', 'bc', 'build-essential', 'ca-certificates', 'coreutils', 'curl', 'dirmngr', 'gnupg', 'libpam-modules', 'libssl-dev', 'lsb-release', 'multipath-tools-boot', 'nano', 'pbzip2', 'pigz', 'pwgen', 'python-is-python3', 'python3', 'rsync', 'ruby', 'screen', 'sudo', 'unzip', 'xz-utils']:
        ensure  => installed,
        require => Package['snapd']
    }

    /* Get OS name */
    case $operatingsystem {
        'Ubuntu': {
            /* Set some variables */
            $os_parent = 'ubuntu'
            $os_repo = 'main universe restricted'
            if ($architecture == 'amd64') {
                $os_url = 'http://archive.ubuntu.com/ubuntu/'
                $os_url_security = 'http://security.ubuntu.com/ubuntu'
            } else {
                $os_url = 'http://ports.ubuntu.com/ubuntu-ports/'
                $os_url_security = 'http://ports.ubuntu.com/ubuntu-ports/'
            }

            /* Do thing based on version */
            if ($operatingsystemrelease =~ /^23.04.*/) { # Stable
                $backports_allow = false
                $gcc_version = 12
                $mongodb_allow = true
                if ($architecture == 'amd64') {
                    $mysql_allow = true
                } else {
                    $mysql_allow = false
                }
                $nginx_allow = true
                $nodejs_allow = true
                $openjdk_allow = true
                $os_name = 'lunar'
                $os_version = $::os['release']['major']
                $proxmox_allow = false
                $puppetserver_dir = 'puppetserver'
                $puppetserver_jdk = true
                $puppetserver_package = 'puppetserver'
                $sury_allow = false
            } elsif ($operatingsystemrelease =~ /^22.04.*/) { # LTS
                $backports_allow = false
                $gcc_version = 12
                $mongodb_allow = true
                if ($architecture == 'amd64') {
                    $mysql_allow = true
                } else {
                    $mysql_allow = false
                }
                $nginx_allow = true
                $nodejs_allow = true
                $openjdk_allow = true
                $os_name = 'jammy'
                $os_version = $::os['release']['major']
                $proxmox_allow = false
                $puppetserver_dir = 'puppet'
                $puppetserver_jdk = false
                $puppetserver_package = 'puppet-master'
                $sury_allow = true
            } else {
                $backports_allow = false
                $gcc_version = undef
                $mongodb_allow = false
                $mysql_allow = false
                $nginx_allow = false
                $nodejs_allow = false
                $openjdk_allow = false
                $os_name = 'unknown'
                $os_version = 0
                $proxmox_allow = false
                $puppetserver_dir = 'puppet'
                $puppetserver_jdk = false
                $puppetserver_package = 'puppet-master'
                $sury_allow = false
            }

            /* Remove unnecessary snapd and unminimize files */
            file { ['/usr/local/sbin/unminimize', '/etc/update-motd.d/60-unminimize', '/etc/xdg/autostart/snap-userd-autostart.desktop', '/etc/apt/apt.conf.d/20snapd.conf']:
                ensure      => absent,
                require     => [Package['libpam-modules'], Package['snapd']]
            }

            /* Remove man */
            exec { 'remove_man':
                command     => 'rm /usr/bin/man',
                onlyif      => ['[ -e /usr/bin/man ]', '[ -e /etc/dpkg/dpkg.cfg.d/excludes ]']
            }

            /* Install extra packages */
            package { ['netplan.io', "linux-image-generic-hwe-${os_version}"]:
                ensure  => installed,
                require => Package['snapd']
            }
        }
        'Debian': {
            /* Set some variables */
            $os_parent = 'debian'
            $os_repo = 'main contrib non-free-firmware'
            $os_url = 'http://deb.debian.org/debian/'
            $os_url_security = 'http://deb.debian.org/debian-security/'

            /* Do thing based on version */
            if ($operatingsystemrelease =~ /^12.*/) {
                $backports_allow = false
                $gcc_version = undef
                $mongodb_allow = true
                if ($architecture == 'amd64') {
                    $mysql_allow = true
                } else {
                    $mysql_allow = false
                }
                $nginx_allow = true
                $nodejs_allow = true
                $openjdk_allow = true
                $os_name = 'bookworm'
                $os_version = 12
                $proxmox_allow = false
                $puppetserver_dir = 'puppetserver'
                $puppetserver_jdk = true
                $puppetserver_package = 'puppetserver'
                $sury_allow = true
            } else {
                $backports_allow = false
                $gcc_version = undef
                $mongodb_allow = false
                $mysql_allow = false
                $nginx_allow = false
                $nodejs_allow = false
                $openjdk_allow = false
                $os_name = 'unknown'
                $os_version = 0
                $proxmox_allow = false
                $puppetserver_dir = 'puppet'
                $puppetserver_jdk = false
                $puppetserver_package = 'puppet-master'
                $sury_allow = false
            }

            /* Remove netplan.io */
            package { 'netplan.io':
                ensure  => purged,
                require => Package['snapd']
            }
        }
        default: {
            $backports_allow = false
            $gcc_version = undef
            $mongodb_allow = false
            $mysql_allow = false
            $nginx_allow = false
            $nodejs_allow = false
            $openjdk_allow = false
            $os_name = 'unknown'
            $os_version = 0
            $proxmox_allow = false
            $puppetserver_dir = 'puppet'
            $puppetserver_jdk = false
            $puppetserver_package = 'puppet-master'
            $sury_allow = false
        }
    }

    /* Install gcc packages */
    if ($gcc_version == undef) {
        package { 'gcc':
            ensure  => installed,
            require => Package['snapd']
        }
    } else {
        package { ['gcc', "gcc-${gcc_version}"]:
            ensure  => installed,
            require => Package['snapd']
        }
    }

    /* Setup sudoers config file */
    file { '/etc/sudoers':
        ensure  => file,
        mode    => '0440',
        owner   => 'root',
        group   => 'root',
        content => template('basic_settings/sudoers')
    }

    /* Setup sudoers dir */
    if ($sudoers_dir_enable) {
        file { '/etc/sudoers.d':
            ensure  => directory,
            purge   => true,
            recurse => true,
            force   => true,
        }
    }

    /* Based on OS parent use correct source list */
    file { '/etc/apt/sources.list':
        ensure  => file,
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template("basic_settings/source/${os_parent}.list")
    }

    /* Reload source list */
    exec { 'source_list_reload':
        command     => 'apt-get update',
        refreshonly => true
    }

    /* Check if we need backports */
    if ($backports and $backports_allow) {
        $backports_install_options = ['-t', "${os_name}-backports"]
        exec { 'source_backports':
            command     => "printf \"deb ${os_url} ${os_name}-backports ${os_repo}\\n\" > /etc/apt/sources.list.d/${os_name}-backports.list",
            unless      => "[ -e /etc/apt/sources.list.d/${os_name}-backports.list ]",
            notify      => Exec['source_list_reload']
        }
    } else {
        $backports_install_options = undef
        exec { 'source_backports':
            command     => "rm /etc/apt/sources.list.d/${os_name}-backports.list",
            onlyif      => "[ -e /etc/apt/sources.list.d/${os_name}-backports.list ]",
            notify      => Exec['source_list_reload']
        }
    }

    /* Install packages */
    package { ['systemd', 'systemd-cron', 'systemd-sysv', 'libpam-systemd', 'git']:
        ensure          => installed,
        install_options => $backports_install_options,
        require         => Exec['source_backports']
    }

    /* Remove unnecessary packages */
    package { ['anacron', 'cron']:
        ensure  => purged,
        require => Package['systemd-cron']
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
        command         => 'systemctl daemon-reload',
        refreshonly     => true,
        require         => Package['systemd']
    }

    /* Setup message */
    class { 'basic_settings::message':
        server_fdqn     => $server_fdqn,
        mail_to         => $systemd_notify_mail,
        mail_package    => $mail_package,
        require         => Package['snapd']
    }

    /* Set timezone */
    class { 'basic_settings::timezone':
        os_parent       => $os_parent,
        timezone        => $server_timezone,
        ntp_extra_pools => $systemd_ntp_extra_pools,
        install_options => $backports_install_options,
        require         => Exec['source_backports']
    }

    /* Setup kernel */
    class { 'basic_settings::kernel':
        hugepages               => $kernel_hugepages,
        tcp_congestion_control  => $kernel_tcp_congestion_control
    }

    /* Set network */
    class { 'basic_settings::network':
        firewall_package    => $firewall_package,
        install_options     => $backports_install_options,
        require             => Exec['source_backports']
    }

    /* Check if OS is Ubuntul For the next step we need systemd package */
    if ($os_parent == 'ubuntu') {
        /* Disable motd news */
        file { '/etc/default/motd-news':
            ensure  => file,
            mode    => '0644',
            content => "ENABLED=0\n",
            require => Package['systemd']
        }

        /* Ensure that motd-news is stopped */
        service { 'motd-news.timer':
            ensure      => stopped,
            enable      => false,
            require     => File['/etc/default/motd-news'],
            subscribe   => File['/etc/default/motd-news']
        }
    }

    /* Disable floppy */
    file { '/etc/modprobe.d/blacklist-floppy.conf':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => "blacklist floppy\n"
    }

    /* Enable multipathd service */
    service { 'multipathd':
        ensure  => true,
        enable  => true,
        require => Package['multipath-tools-boot']
    }

    /* Create multipart config */
    file { '/etc/multipath.conf':
        ensure  => file,
        source  => 'puppet:///modules/basic_settings/multipath.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        notify  => Service['multipathd']
    }

    /* Ensure that getty is stopped */
    service { 'getty@tty*':
        ensure      => stopped,
        enable      => false
    }

    /* Check if we need sury */
    if ($sury_enable and $sury_allow) {
        /* Add sury PHP repo */
        case $os_parent {
            'ubuntu': {
                exec { 'source_sury_php':
                    command     => "printf \"deb https://ppa.launchpadcontent.net/ondrej/php/ubuntu ${os_name} main\\n\" > /etc/apt/sources.list.d/sury_php.list; apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 14AA40EC0831756756D7F66C4F4EA0AAE5267A6C ",
                    unless      => '[ -e /etc/apt/sources.list.d/sury_php.list ]',
                    notify      => Exec['source_list_reload'],
                    require     => [Package['curl'], Package['gnupg']]
                }
            }
            default: {
                exec { 'source_sury_php':
                    command     => "curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb; dpkg -i /tmp/debsuryorg-archive-keyring.deb; printf \"deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ ${os_name} main\\n\" > /etc/apt/sources.list.d/sury_php.list",
                    unless      => '[ -e /etc/apt/sources.list.d/sury_php.list ]',
                    notify      => Exec['source_list_reload'],
                    require     => [Package['curl'], Package['gnupg']]
                }
            }
        }

    } else {
        /* Remove sury php repo */
        exec { 'source_sury_php':
            command     => 'rm /etc/apt/sources.list.d/sury_php.list',
            onlyif      => '[ -e /etc/apt/sources.list.d/sury_php.list ]',
            notify      => Exec['source_list_reload']
        }
    }

    /* Check if variable nginx is true; if true, install new source list and key */
    if ($nginx_enable and $nginx_allow) {
        exec { 'source_nginx':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/${os_parent} ${os_name} nginx\\n\" > /etc/apt/sources.list.d/nginx.list; curl -s https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null",
            unless      => '[ -e /etc/apt/sources.list.d/nginx.list ]',
            notify      => Exec['source_list_reload'],
            require     => [Package['curl'], Package['gnupg']]
        }
    } else {
        /* Remove nginx repo */
        exec { 'source_nginx':
            command     => 'rm /etc/apt/sources.list.d/nginx.list',
            onlyif      => '[ -e /etc/apt/sources.list.d/nginx.list ]',
            notify      => Exec['source_list_reload'],
        }
    }

    /* Check if variable proxmox is true; if true, install new source list and key */
    if ($proxmox_enable and $proxmox_allow) {
        exec { 'source_proxmox':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/proxmox-release-bookworm.gpg] http://download.proxmox.com/debian/pve ${os_name} pve-no-subscription\\n\" > /etc/apt/sources.list.d/pve-install-repo.list; curl -sSLo /usr/share/keyrings/proxmox-release-bookworm.gpg https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg",
            unless      => '[ -e /etc/apt/sources.list.d/pve-install-repo.list.list ]',
            notify      => Exec['source_list_reload'],
            require     => [Package['curl'], Package['gnupg']]
        }
    } else {
        /* Remove proxmox repo */
        exec { 'source_proxmox':
            command     => 'rm /etc/apt/sources.list.d/pve-install-repo.list.list',
            onlyif      => '[ -e /etc/apt/sources.list.d/pve-install-repo.list.list ]',
            notify      => Exec['source_list_reload']
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
            command     => "printf \"deb [signed-by=/usr/share/keyrings/mysql.gpg] http://repo.mysql.com/apt/${os_parent} ${os_name} mysql-${mysql_version}\\n\" > /etc/apt/sources.list.d/mysql.list; cat /usr/share/keyrings/mysql.key | gpg --dearmor | sudo tee /usr/share/keyrings/mysql.gpg >/dev/null",
            unless      => '[ -e /etc/apt/sources.list.d/mysql.list ]',
            notify      => Exec['source_list_reload'],
            require     => [Package['curl'], Package['gnupg'], File['source_mysql_key']]
        }
    } else {
        /* Remove mysql repo */
        exec { 'source_mysql':
            command     => 'rm /etc/apt/sources.list.d/mysql.list',
            onlyif      => '[ -e /etc/apt/sources.list.d/mysql.list ]',
            notify      => Exec['source_list_reload']
        }
    }

    /* Check if variable mongodb is true; if true, install new source list and key */
    if ($mongodb_enable and $mongodb_allow) {
        exec { 'source_mongodb':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/mongodb.gpg] http://repo.mongodb.org/apt/debian ${os_name}/mongodb-org/${mongodb_version} main\\n\" > /etc/apt/sources.list.d/mongodb.list; curl -s https://pgp.mongodb.com/server-${mongodb_version}.asc | gpg --dearmor | sudo tee /usr/share/keyrings/mongodb.gpg >/dev/null",
            unless      => '[ -e /etc/apt/sources.list.d/mongodb.list ]',
            notify      => Exec['source_list_reload'],
            require     => [Package['curl'], Package['gnupg']]
        }

        /* Install mongodb-org-server package */
        package { 'mongodb-org-server':
            ensure  => installed,
            require => Exec['source_mongodb']
        }
    } else {
        /* Remove mongodb-org-server package */
        package { 'mongodb-org-server':
            ensure  => purged
        }

        /* Remove mongodb repo */
        exec { 'source_mongodb':
            command     => 'rm /etc/apt/sources.list.d/mongodb.list',
            onlyif      => '[ -e /etc/apt/sources.list.d/mongodb.list ]',
            notify      => Exec['source_list_reload']
        }
    }

    /* Check if variable nodejs is true; if true, install new source list and key */
    if ($nodejs_enable and $nodejs_allow) {
        exec { 'source_nodejs':
            command     => "curl -fsSL https://deb.nodesource.com/setup_${nodejs_version}.x | bash - &&\\",
            unless      => '[ -e /etc/apt/sources.list.d/nodesource.list ]',
            notify      => Exec['source_list_reload'],
            require     => Package['curl']
        }

        /* Install nodejs package */
        package { 'nodejs':
            ensure  => installed,
            require => Exec['source_nodejs']
        }
    } else {
        /* Remove nodejs package */
        package { 'nodejs':
            ensure  => purged
        }

        /* Remove nodejs repo */
        exec { 'source_nodejs':
            command     => 'rm /etc/apt/sources.list.d/nodesource.list',
            onlyif      => '[ -e /etc/apt/sources.list.d/nodesource.list ]',
            notify      => Exec['source_list_reload'],
            require     => Package['nodejs']
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

        /* Remove java extensions */
        package { 'ca-certificates-java':
            ensure  => installed,
            require => Package['openjdk']
        }
    } else {
        /* Remove openjdk package */
        package { 'openjdk':
            name    => 'openjdk*',
            ensure  => purged
        }

        /* Remove java extensions */
        package { 'ca-certificates-java':
            ensure  => purged,
            require => Package['openjdk']
        }
    }

    /* Setup APT */
    class { 'basic_settings::apt':
        unattended_upgrades_block_extra_packages   => $unattended_upgrades_block_extra_packages,
        unattended_upgrades_block_packages         => $unattended_upgrades_block_packages,
        server_fdqn                                => $server_fdqn,
        mail_to                                    => $systemd_notify_mail,
        require                                    => Package['snapd']
    }

    /* Setup Puppet */
    class { 'basic_settings::puppet':
        server_enable  => $puppetserver_enable,
        server_package => $puppetserver_package,
        server_dir     => $puppetserver_dir
    }
}
