class basic_settings(
        $backports                                  = false,
        $cluster_id                                 = 'core',
        $firewall_package                           = 'nftables',
        $kernel_hugepages                           = '0',
        $kernel_tcp_congestion_control              = 'brr',
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
        $proxmox_enable                             = false,
        $puppetserver_enable                        = false,
        $server_fdqn                                = $fqdn,
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
    package { ['apport', 'chrony', 'ifupdown', 'lxd-installer', 'ntp', 'snapd']:
        ensure  => absent
    }

    /* Basic system packages */
    package { ['apt-listchanges', 'apt-transport-https', 'bash-completion', 'bc', 'build-essential', 'ca-certificates', 'curl', 'debian-archive-keyring', 'debian-keyring', 'dirmngr', 'dnsutils', 'ethtool', 'gnupg', 'iputils-ping', 'libpam-modules', 'libhugetlbfs-bin', 'libssl-dev', 'lsb-release', 'mailutils', 'mtr', 'multipath-tools-boot', 'nano', 'networkd-dispatcher', 'pbzip2', 'pigz', 'pwgen', 'python-is-python3', 'python3', 'rsync', 'ruby', 'screen', 'sudo', 'unattended-upgrades', 'unzip', 'xdg-user-dirs', 'xz-utils']:
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
                $os_name = 'lunar'
                $backports_allow = false
                $sury_allow = false
                $nginx_allow = true
                $proxmox_allow = false
                if ($architecture == 'amd64') {
                    $mysql_allow = true
                } else {
                    $mysql_allow = false
                }
                $mongodb_allow = true
                $nodejs_allow = true
                $openjdk_allow = true
                $puppetserver_dir = 'puppetserver'
                $puppetserver_package = 'puppetserver'
            } elsif ($operatingsystemrelease =~ /^22.04.*/) { # LTS
                $os_name = 'jammy'
                $backports_allow = true
                $sury_allow = false
                $nginx_allow = true
                $proxmox_allow = false
                if ($architecture == 'amd64') {
                    $mysql_allow = true
                } else {
                    $mysql_allow = false
                }
                $mongodb_allow = true
                $nodejs_allow = true
                $openjdk_allow = true
                $puppetserver_dir = 'puppet'
                $puppetserver_package = 'puppet-master'
            } else {
                $os_name = 'unknown'
                $backports_allow = false
                $sury_allow = false
                $nginx_allow = false
                $proxmox_allow = false
                $mysql_allow = false
                $mongodb_allow = false
                $nodejs_allow = false
                $openjdk_allow = false
                $puppetserver_dir = 'puppet'
                $puppetserver_package = 'puppet-master'
            }

            /* Remove unminimize files */
            file { ['/usr/local/sbin/unminimize', '/etc/update-motd.d/60-unminimize']:
                ensure      => absent,
                require     => Package['libpam-modules']
            }

            /* Remove unnecessary snapd files */
            file { '/etc/xdg/autostart/snap-userd-autostart.desktop':
                ensure      => absent,
                require     => Package['snapd']
            }

            /* Remove man */
            exec { 'remove_man':
                command     => 'rm /usr/bin/man',
                onlyif      => ['[ -e /usr/bin/man ]', '[ -e /etc/dpkg/dpkg.cfg.d/excludes ]']
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
                $os_name = 'bookworm'
                $backports_allow = false
                $sury_allow = true
                $nginx_allow = true
                $proxmox_allow = true
                if ($architecture == 'amd64') {
                    $mysql_allow = true
                } else {
                    $mysql_allow = false
                }
                $mongodb_allow = true
                $nodejs_allow = true
                $openjdk_allow = true
                $puppetserver_dir = 'puppetserver'
                $puppetserver_package = 'puppetserver'
            } else {
                $os_name = 'unknown'
                $backports_allow = false
                $sury_allow = false
                $nginx_allow = false
                $proxmox_allow = false
                $mysql_allow = false
                $mongodb_allow = false
                $nodejs_allow = false
                $openjdk_allow = false
                $puppetserver_dir = 'puppet'
                $puppetserver_package = 'puppet-master'
            }
        }
        default: {
            $os_parent = 'unknown'
            $os_repo = ''
            $os_url = ''
            $os_url_security = ''
            $os_name = 'unknown'
            $backports_allow = false
            $sury_allow = false
            $nginx_allow = false
            $proxmox_allow = false
            $mysql_allow = false
            $mongodb_allow = false
            $nodejs_allow = false
            $openjdk_allow = false
            $puppetserver_dir = ''
            $puppetserver_package = ''
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
        exec { 'source_backports':
            command     => "printf \"deb ${os_url} ${os_name}-backports ${os_repo}\\n\" > /etc/apt/sources.list.d/${os_name}-backports.list",
            unless      => "[ -e /etc/apt/sources.list.d/${os_name}-backports.list ]",
            notify      => Exec['source_list_reload']
        }
    } else {
        exec { 'source_backports':
            command     => "rm /etc/apt/sources.list.d/${os_name}-backports.list",
            onlyif      => "[ -e /etc/apt/sources.list.d/${os_name}-backports.list ]",
            notify      => Exec['source_list_reload']
        }
    }

    /* Do special thinks based on firewall package */
    case $firewall_package {
        'nftables': {
            $firewall_command = 'systemctl is-active --quiet nftables.service && nft --file /etc/firewall.conf'
            package { ['iptables', 'firwalld']:
                ensure => absent
            }
        }
        'iptables': {
            $firewall_command = 'iptables-restore < /etc/firewall.conf'
            package { ['nftables', 'firwalld']:
                ensure => absent
            }
        }
        'firewalld': {
            $firewall_command = ''
        }
    }

    /* Install firewall and git */
    if ($backports and $allow_backports) {
        package { ['systemd', 'systemd-sysv', 'systemd-timesyncd', 'libpam-systemd', 'git', "${firewall_package}"]:
            ensure          => installed,
            install_options => ['-t', "${os_name}-backports"],
            require         => Exec['source_backports']
        }
    } else {
        package { ['systemd', 'systemd-sysv', 'systemd-timesyncd', 'libpam-systemd', 'git', "${firewall_package}"]:
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

    /* Create systemd service for notification */
    basic_settings::systemd_service { 'notify-failed@':
        description => 'Send systemd notifications to mail',
        service     => {
            'Type'      => 'oneshot',
            'ExecStart' => "/usr/bin/bash -c 'LC_CTYPE=C systemctl status --full %i | /usr/bin/mail -s \"Service %i failed on ${server_fdqn}\" -r \"systemd@${server_fdqn}\" ${systemd_notify_mail}'",
        }
    }

    /* Systemd NTP settings */
    $systemd_ntp_all_pools = flatten($systemd_ntp_extra_pools, [
        "0.${os_parent}.pool.ntp.org",
        "1.${os_parent}.pool.ntp.org",
        "2.${os_parent}.pool.ntp.org",
        "3.${os_parent}.pool.ntp.org",
    ]);
    $systemd_ntp_list = join($systemd_ntp_all_pools, ' ')

    /* Create systemd timesyncd config  */
    file { '/etc/systemd/timesyncd.conf':
        ensure  => file,
        content  => template('basic_settings/systemd/timesyncd.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        notify  => Exec['systemd_daemon_reload'],
        require => Package['systemd-timesyncd']
    }

    /* Ensure that systemd-timesyncd is always running */
    service { 'systemd-timesyncd':
        ensure      => running,
        enable      => true,
        require     => File['/etc/systemd/timesyncd.conf'],
        subscribe   => File['/etc/systemd/timesyncd.conf']
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
        require     => Package['networkd-dispatcher']
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

    /* Check if we need sury */
    if ($sury_enable and $sury_allow) {
        /* Add sury PHP repo */
        exec { 'source_sury_php':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ ${os_name} main\\n\" > /etc/apt/sources.list.d/sury_php.list; curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg",
            unless      => '[ -e /etc/apt/sources.list.d/sury_php.list ]',
            notify      => Exec['source_list_reload'],
            require     => [Package['curl'], Package['gnupg']]
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
            ensure  => absent
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
            ensure  => absent
        }

        /* Remove nodejs repo */
        exec { 'source_nodejs':
            command     => 'rm /etc/apt/sources.list.d/nodesource.list',
            onlyif      => '[ -e /etc/apt/sources.list.d/nodesource.list ]',
            notify      => Exec['source_list_reload'],
            require     => Package['nodejs']
        }
    }

    /* Create group for hugetlb only when hugepages is given */
    if ($kernel_hugepages != '0') {
        # Set variable 
        $kernel_hugepages_shm_group = '7000'

        # Remove group 
        group { 'hugetlb':
            ensure      => present,
            gid         => $kernel_hugepages_shm_group
        }

        /* Create drop in for dev-hugepages mount */
        basic_settings::systemd_drop_in { 'hugetlb_hugepages':
            target_unit     => 'dev-hugepages.mount',
            mount         => {
                'Options' => "mode=1770,gid=${kernel_hugepages_shm_group}"
            },
            require         => Group['hugetlb']
        }

        /* Create systemd service */
        basic_settings::systemd_service { 'dev-hugepages-shmmax':
            description => 'Hugespages recommended shmmax service',
            service     => {
                'Type'      => 'oneshot',
                'ExecStart' => '/usr/bin/hugeadm --set-recommended-shmmax'
            },
            unit        => {
                'Requires'  => 'dev-hugepages.mount',
                'After'     => 'dev-hugepages.mount'
            },
            install     => {
                'WantedBy' => 'dev-hugepages.mount'
            }
        }

        /* Reload sysctl deamon */
        exec { 'sysctl_reload':
            command => 'bash -c "/usr/bin/systemctl start dev-hugepages-shmmax.service && sysctl --system"',
            refreshonly => true
        }
    } else {
        # Set variable
        $kernel_hugepages_shm_group = '0'

        # Remove group 
        group { 'hugetlb':
            ensure => absent
        }

        /* Remove drop in for dev-hugepages mount */
        basic_settings::systemd_drop_in { 'hugetlb_hugepages':
            ensure          => absent,
            target_unit     => 'dev-hugepages.mount',
            require         => Group['hugetlb']
        }

        /* Reload sysctl deamon */
        exec { 'sysctl_reload':
            command => 'sysctl --system',
            refreshonly => true
        }
    }

    /* Create sysctl config  */
    file { '/etc/sysctl.conf':
        ensure  => file,
        content  => template('basic_settings/sysctl.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec['sysctl_reload']
    }

    /* Create sysctl config  */
    file { '/etc/sysctl.d':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0600'
    }

    /* Create sysctl network config  */
    file { '/etc/sysctl.d/20-network-security.conf':
        ensure  => file,
        content  => template('basic_settings/sysctl/network.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec['sysctl_reload']
    }

    /* Setup TCP */
    case $kernel_tcp_congestion_control {
        'bbr': {
            exec { 'tcp_congestion_control':
                command     => 'printf "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" > /etc/sysctl.d/20-tcp_congestion_control.conf; chmod 600 /etc/sysctl.d/20-tcp_congestion_control.conf; sysctl -p /etc/sysctl.d/20-tcp_congestion_control.conf',
                onlyif      => ['test ! -f /etc/sysctl.d/20-tcp_congestion_control.conf', 'test 4 -eq $(cat /boot/config-$(uname -r) | grep -c -E \'CONFIG_TCP_CONG_BBR|CONFIG_NET_SCH_FQ\')']
            }
        }
        default: {
            exec { 'tcp_congestion_control':
                command     => 'rm /etc/sysctl.d/20-tcp_congestion_control.conf',
                onlyif      => '[ -e /etc/sysctl.d/20-tcp_congestion_control.conf]',
                notify      => Exec['sysctl_reload']
            }
        }
    }

    /* Check if variable openjdk is true; if true, install new package */
    if ($puppetserver_enable or ($openjdk_enable and $openjdk_allow)) {
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
            ensure  => absent
        }

        /* Remove java extensions */
        package { 'ca-certificates-java':
            ensure  => absent,
            require => Package['openjdk']
        }
    }

    /* Activate performance modus */
    exec { 'kernel_performance':
        command     => "bash -c 'for (( i=0; i<`nproc`; i++ )); do if [ -d /sys/devices/system/cpu/cpu\${i}/cpufreq ]; then echo \"performance\" > /sys/devices/system/cpu/cpu\${i}/cpufreq/scaling_governor; fi; done > /tmp/kernel_performance.state'",
        onlyif      => "bash -c 'if [[ ! $(grep ^vendor_id /proc/cpuinfo) ]]; then exit 1; fi; if [[ $(grep ^vendor_id /proc/cpuinfo | uniq | awk \"(\$3!='GenuineIntel' && \$3!='AuthenticAMD')\") ]]; then exit 1; fi; if [ -f /tmp/kernel_performance.state ]; then exit 1; else exit 0; fi'"
    }

    /* Activate turbo modus */
    exec { 'kernel_turbo':
        command => "bash -c 'echo \"1\" > /sys/devices/system/cpu/cpufreq/boost'",
        onlyif  => "bash -c 'if [ ! -f /sys/devices/system/cpu/cpufreq/boost ]; then exit 1; fi; if [ $(cat /sys/devices/system/cpu/cpufreq/boost) -eq \"1\" ]; then exit 1; else exit 0; fi'"
    }

    /* Disable CPU core C states */
    exec { 'kernel_c_states':
        command => "bash -c 'for (( i=0; i<`nproc`; i++ )); do if [ -d /sys/devices/system/cpu/cpu\${i}/cpuidle/state2 ]; then echo \"1\" > /sys/devices/system/cpu/cpu\${i}/cpuidle/state2/disable; fi; done > /tmp/kernel_c_states.state'",
        onlyif  => "bash -c 'if [[ ! $(grep ^vendor_id /proc/cpuinfo) ]]; then exit 1; fi; if [ $(grep ^vendor_id /proc/cpuinfo | uniq | \"(\$3!='GenuineIntel')\") ]; then exit 1; fi; if [ -f /tmp/kernel_c_states.state ]; then exit 1; else exit 0; fi'"
    }

    /* Improve kernel io */
    exec { 'kernel_io':
        command => 'bash -c "dev=$(cat /tmp/kernel_io.state); echo \'none\' > /sys/block/\$dev/queue/scheduler;"',
        onlyif  => 'bash -c "dev=$(eval $(lsblk -oMOUNTPOINT,PKNAME -P -M | grep \'MOUNTPOINT="/"\'); echo $PKNAME | sed \'s/[0-9]*$//\'); echo \$dev > /tmp/kernel_io.state; if [ $(grep -c \'\\[none\\]\' /sys/block/$(cat /tmp/kernel_io.state)/queue/scheduler) -eq 0 ]; then exit 0; fi; exit 1"'
    }

    /* Activate transparent hugepage modus */
    exec { 'kernel_transparent_hugepage':
        command => "bash -c 'echo \"madvise\" > /sys/kernel/mm/transparent_hugepage/enabled'",
        onlyif  => 'bash -c "if [ $(grep -c \'\\[madvise\\]\' /sys/kernel/mm/transparent_hugepage/enabled) -eq 0 ]; then exit 0; fi; exit 1"'
    }

    /* Activate transparent hugepage modus */
    exec { 'kernel_transparent_hugepage_defrag':
        command => "bash -c 'echo \"madvise\" > /sys/kernel/mm/transparent_hugepage/defrag'",
        onlyif  => 'bash -c "if [ $(grep -c \'\\[madvise\\]\' /sys/kernel/mm/transparent_hugepage/defrag) -eq 0 ]; then exit 0; fi; exit 1"'
    }

    /* Create unattended upgrades config  */
    $unattended_upgrades_block_all_packages = flatten($unattended_upgrades_block_extra_packages, $unattended_upgrades_block_packages);
    file { '/etc/apt/apt.conf.d/99unattended-upgrades':
        ensure  => file,
        content  => template('basic_settings/unattended-upgrades'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['unattended-upgrades']
    }

    /* Ensure that apt-daily timers is always running */
    service { ['apt-daily.timer', 'apt-daily-upgrade.timer']:
        ensure      => running,
        enable      => true,
        require     => Package['unattended-upgrades']
    }

    /* Disable service */
    service { 'puppet':
        ensure  => undef,
        enable  => false
    }

    /* Create drop in for services target */
    basic_settings::systemd_drop_in { 'puppet_dependency':
        target_unit     => "${cluster_id}-system.target",
        unit            => {
            'Wants'   => 'puppet.service'
        },
        require         => Basic_settings::Systemd_target["${cluster_id}-system"]
    }

    /* Create drop in for puppet service */
    basic_settings::systemd_drop_in { 'puppet_settings':
        target_unit     => 'puppet.service',
        unit            => {
            'OnFailure' => 'notify-failed@%i.service'
        },
        service         => {
            'Nice'          => 19,
            'LimitNOFILE'   => 10000
        }
    }

    /* Do only the next steps when we are puppet server */
    if ($puppetserver_enable) {
        /* Disable service */
        service {  "${puppetserver_package}":
            ensure  => undef,
            enable  => false
        }

        /* Create drop in for services target */
        basic_settings::systemd_drop_in { 'puppetserver_dependency':
            target_unit     => "${cluster_id}-system.target",
            unit            => {
                'Wants'   => "${puppetserver_package}.service"
            },
            require         => Basic_settings::Systemd_target["${cluster_id}-system"]
        }

        /* Create drop in for puppet server service */
        basic_settings::systemd_drop_in { 'puppetserver_settings':
            target_unit     => "${puppetserver_package}.service",
            unit            => {
                'OnFailure' => 'notify-failed@%i.service'
            },
            service         => {
                'Nice'          => '-8',
            }
        }

        /* Create systemd puppet server clean reports service */
        basic_settings::systemd_service { 'puppetserver-clean-reports':
            description => 'Clean puppetserver reports service',
            service     => {
                'Type'      => 'oneshot',
                'User'      => 'puppet',
                'ExecStart' => "/usr/bin/find /var/lib/${puppetserver_dir}/reports -type f -name \\\*.yaml -ctime +1 -delete",
                'Nice'      => '19'
            },
        }

        /* Create systemd puppet server clean reports timer */
        basic_settings::systemd_timer { 'puppetserver-clean-reports':
            description => 'Clean puppetserver reports timer',
            timer       => {
                'OnCalendar' => '*-*-* 10:00'
            }
        }

        /* Create drop in for puppet service */
        basic_settings::systemd_drop_in { 'puppet_puppetserver_dependency':
            target_unit     => 'puppet.service',
            unit         => {
                'After'     => "${puppetserver_package}.service",
                'BindsTo'   => "${puppetserver_package}.service"
            }
        }
    }
}
