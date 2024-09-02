class basic_settings::kernel(
    Optional[String]            $antivirus_package          = undef,
    Optional[String]            $bootloader                 = 'grub',
    Optional[Integer]           $connection_max             = 4096,
    Optional[String]            $cpu_governor               = 'performance',
    Optional[Boolean]           $guest_agent_enable         = false,
    Optional[Integer]           $hugepages                  = 0,
    Optional[Array]             $install_options            = undef,
    Optional[Enum['all','4']]   $ip_version                 = 'all',
    Optional[String]            $network_mode               = 'strict',
    Optional[String]            $security_lockdown          = 'integrity',
    Optional[String]            $tcp_congestion_control     = 'brr',
    Optional[Integer]           $tcp_fastopen               = 3
) {
    /* Install extra packages when Ubuntu */
    if ($facts['os']['name'] == 'Ubuntu') {
        $os_version = $facts['os']['release']['major']
        if ($os_version != '24.04') {
            package { ["linux-image-generic-hwe-${os_version}", "linux-headers-generic-hwe-${os_version}"]:
                ensure  => installed
            }
        }
    }

    /* Try to get guest package */
    if ($facts['is_virtual']) {
        case $facts::virtual {
            'vmware': {
                $guest_agent_package = 'open-vm-tools'
            }
            default: {
                $guest_agent_package = 'qemu-guest-agent'
            }
        }
    } else {
        $guest_agent_package = undef
    }

    /* Override some settings when we have antivirus or we are virtual machine */
    case $antivirus_package {
        'eset': {
            $security_lockdown_correct = 'none'
        }
        default: {
            if ($guest_agent_enable and $guest_agent_package != undef) {
                $security_lockdown_correct = 'none'
            } else {
                $security_lockdown_correct = $security_lockdown
            }
        }
    }

    /* Get IP versions */
    case $ip_version {
        '4': {
            $ip_version_v4 = true
            $ip_version_v6 = false
        }
        default: {
            $ip_version_v4 = true
            $ip_version_v6 = true
        }
    }

    /* Create group for hugetlb only when hugepages is given */
    if (defined(Package['systemd']) and $hugepages > 0) {
        # Set variable 
        $hugepages_shm_group = 7000

        /* Install libhugetlbfs package */
        package { 'libhugetlbfs-bin':
            ensure => installed
        }

        # Remove group 
        group { 'hugetlb':
            ensure      => present,
            gid         => $hugepages_shm_group,
            require     => Package['libhugetlbfs-bin']
        }

        /* Create drop in for dev-hugepages mount */
        basic_settings::systemd_drop_in { 'hugetlb_hugepages':
            target_unit     => 'dev-hugepages.mount',
            mount         => {
                'Options' => "mode=1770,gid=${hugepages_shm_group}"
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
        exec { 'kernel_sysctl_reload':
            command => '/usr/bin/bash -c "/usr/bin/systemctl start dev-hugepages-shmmax.service && /usr/sbin/sysctl --system"',
            refreshonly => true
        }
    } else {
        # Set variable
        $hugepages_shm_group = 0

        /* Install libhugetlbfs package */
        package { 'libhugetlbfs-bin':
            ensure => purged
        }

        # Remove group 
        group { 'hugetlb':
            ensure  => absent,
            require => Package['libhugetlbfs-bin']
        }

        /* Remove drop in for dev-hugepages mount */
        if (defined(Package['systemd'])) {
            basic_settings::systemd_drop_in { 'hugetlb_hugepages':
                ensure          => absent,
                target_unit     => 'dev-hugepages.mount',
                require         => Group['hugetlb']
            }
        }

        /* Reload sysctl deamon */
        exec { 'kernel_sysctl_reload':
            command => '/usr/sbin/sysctl --system',
            refreshonly => true
        }
    }

    /* Remove unnecessary packages */
    package { ['apport', 'installation-report', 'linux-tools-common', 'plymouth', 'thermald', 'upower']:
        ensure  => purged
    }

    /* Install system package */
    if (!defined(Package['bc'])) {
        package { 'bc':
            ensure  => installed
        }
    }

    /* Install system package */
    if (!defined(Package['coreutils'])) {
        package { 'coreutils':
            ensure  => installed
        }
    }

    /* Install system package */
    if (!defined(Package['grep'])) {
        package { 'grep':
            ensure  => installed
        }
    }

    /* Install system package */
    if (!defined(Package['lsb-release'])) {
        package { 'lsb-release':
            ensure  => installed
        }
    }

    /* Install system package */
    if (!defined(Package['kmod'])) {
        package { 'kmod':
            ensure  => installed
        }
    }

    /* Install system package */
    if (!defined(Package['sed'])) {
        package { 'sed':
            ensure  => installed
        }
    }

    /* Install system package */
    if (!defined(Package['util-linux'])) {
        package { 'util-linux':
            ensure  => installed
        }
    }

    /* Create sysctl config  */
    file { '/etc/sysctl.conf':
        ensure  => file,
        content  => template('basic_settings/kernel/sysctl.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec['kernel_sysctl_reload']
    }

    /* Create sysctl config  */
    file { '/etc/sysctl.d':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        force   => true,
        purge   => true,
        recurse => true,
        notify  => Exec['kernel_sysctl_reload']
    }

    /* Create sysctl network config  */
    file { '/etc/sysctl.d/90-network.conf':
        ensure  => file,
        content  => template('basic_settings/kernel/sysctl/network.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec['kernel_sysctl_reload']
    }

    /* Create sysctl memory config  */
    file { '/etc/sysctl.d/90-memory.conf':
        ensure  => file,
        content  => template('basic_settings/kernel/sysctl/memory.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec['kernel_sysctl_reload']
    }

    /* Create symlink */
    file { '/etc/sysctl.d/99-sysctl.conf':
        ensure  => 'link',
        target  => '/etc/sysctl.conf',
        force   => true,
        notify  => Exec['kernel_sysctl_reload']
    }

    /* Set apparmor state */
    if (defined(Package['apparmor'])) {
        $apparmor_enable = true
    } else {
        $apparmor_enable = false
    }

    /* Get CPU processor */
    if (empty($facts['processors']['models'])) {
        $cpu_processor = ''
    } else {
        $cpu_processor = $facts['processors']['models'][0]
    }

    /* Set CPU manufacturer */
    if ($cpu_processor =~ 'AMD') {
        $cpu_manufacturer = 'amd'
    } elsif ($cpu_processor =~ 'Intel') {
        $cpu_manufacturer = 'intel'
    } else {
        $cpu_manufacturer = undef
    }

    /* Set CPU settings */
    if (!$facts['is_virtual']) {
        /* Get settings */
        $cpu_governor_correct = $cpu_governor
        case $cpu_governor_correct {
            'performance': {
                case $cpu_manufacturer {
                    'amd', 'intel': {
                        $cpu_boost = 1
                        $cpu_idle_max_cstate = 1
                        $cpu_pstate = 'passive'
                    }
                    default: {
                        $cpu_boost = undef
                        $cpu_idle_max_cstate = undef
                        $cpu_pstate = undef
                    }
                }
            }
            default: {
                $cpu_boost = undef
                $cpu_idle_max_cstate = undef
                $cpu_pstate = undef
            }
        }

        /* Check if boot value is given */
        if ($cpu_boost != undef) {
            exec { 'kernel_cpu_boost':
                command => "/usr/bin/bash -c 'echo \"1\" > /sys/devices/system/cpu/cpufreq/boost'",
                onlyif  => "/usr/bin/bash -c 'if [ ! -f /sys/devices/system/cpu/cpufreq/boost ]; then exit 1; fi; if [ $(cat /sys/devices/system/cpu/cpufreq/boost) -eq \"${cpu_boost}\" ]; then exit 1; else exit 0; fi'"
            }
        }
    } else {
        $cpu_governor_corect = undef
        $cpu_boost = undef
        $cpu_idle_max_cstate = undef
        $cpu_pstate = undef
    }

    /* Setup TCP */
    case $bootloader {
        'grub': {
            /* Set boot loader packages */
            $bootloader_packages = ['/usr/sbin/update-grub']

            /* Install package */
            package { 'grub2-common':
                ensure => installed
            }

            /* Remove unnecessary packages */
            package { 'systemd-boot':
                ensure  => purged,
                require => Package['grub2-common']
            }

            /* Reload sysctl deamon */
            exec { 'kernel_grub_update':
                command => '/usr/sbin/update-grub',
                refreshonly => true
            }

            /* Create custom grub config */
            file { '/etc/default/grub':
                ensure  => file,
                content  => template('basic_settings/kernel/grub'),
                owner   => 'root',
                group   => 'root',
                mode    => '0600',
                notify  => Exec['kernel_grub_update']
            }
        }
        default: {
            $bootloader_packages = []
        }
    }

    /* Create list of packages that is suspicious */
    $suspicious_packages = flatten($bootloader_packages, ['/bin/su']);

    /* Setup TCP */
    case $tcp_congestion_control {
        'bbr': {
            exec { 'tcp_congestion_control':
                command     => '/usr/bin/printf "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" > /etc/sysctl.d/20-tcp_congestion_control.conf; chmod 600 /etc/sysctl.d/20-tcp_congestion_control.conf; sysctl -p /etc/sysctl.d/20-tcp_congestion_control.conf',
                onlyif      => ['test ! -f /etc/sysctl.d/20-tcp_congestion_control.conf', 'test 4 -eq $(cat /boot/config-$(uname -r) | grep -c -E \'CONFIG_TCP_CONG_BBR|CONFIG_NET_SCH_FQ\')']
            }
        }
        default: {
            exec { 'tcp_congestion_control':
                command     => '/usr/bin/rm /etc/sysctl.d/20-tcp_congestion_control.conf',
                onlyif      => '[ -e /etc/sysctl.d/20-tcp_congestion_control.conf ]',
                notify      => Exec['kernel_sysctl_reload']
            }
        }
    }

    /* Improve kernel io */
    exec { 'kernel_io':
        command => '/usr/bin/bash -c "dev=$(cat /tmp/kernel_io.state); echo \'none\' > /sys/block/\$dev/queue/scheduler;"',
        onlyif  => '/usr/bin/bash -c "dev=$(eval $(lsblk -oMOUNTPOINT,PKNAME -P -M | grep \'MOUNTPOINT="/"\'); echo $PKNAME | sed \'s/[0-9]*$//\'); echo \$dev > /tmp/kernel_io.state; if [ $(grep -c \'\\[none\\]\' /sys/block/$(cat /tmp/kernel_io.state)/queue/scheduler) -eq 0 ]; then exit 0; fi; exit 1"'
    }

    /* Activate transparent hugepage modus */
    exec { 'kernel_transparent_hugepage':
        command => "/usr/bin/bash -c 'echo \"madvise\" > /sys/kernel/mm/transparent_hugepage/enabled'",
        onlyif  => '/usr/bin/bash -c "if [ $(grep -c \'\\[madvise\\]\' /sys/kernel/mm/transparent_hugepage/enabled) -eq 0 ]; then exit 0; fi; exit 1"'
    }

    /* Activate transparent hugepage modus */
    exec { 'kernel_transparent_hugepage_defrag':
        command => "/usr/bin/bash -c 'echo \"madvise\" > /sys/kernel/mm/transparent_hugepage/defrag'",
        onlyif  => '/usr/bin/bash -c "if [ $(grep -c \'\\[madvise\\]\' /sys/kernel/mm/transparent_hugepage/defrag) -eq 0 ]; then exit 0; fi; exit 1"'
    }

    /* Kernel security lockdown */
    exec { 'kernel_security_lockdown':
        command => "/usr/bin/bash -c 'echo \"${security_lockdown_correct}\" > /sys/kernel/security/lockdown'",
        onlyif  => "/usr/bin/bash -c \"if [ $(grep -c '\\[${security_lockdown_correct}\\]' /sys/kernel/security/lockdown) -eq 0 ]; then exit 0; fi; exit 1\""
    }


    /* Guest agent */
    if ($guest_agent_package != undef) {
        if ($guest_agent_enable) {
            package { "${guest_agent_package}":
                ensure          => installed,
                install_options => $install_options
            }
        } else {
            package { "${guest_agent_package}":
                ensure  => purged
            }
        }
    }

    /* Setup audit rules */
    if (defined(Package['auditd'])) {
        /* Create kernel rules */
        basic_settings::security_audit { 'kernel':
            rules                   => [
                '# Injection',
                '# These rules watch for code injection by the ptrace facility.',
                '# This could indicate someone trying to do something bad or just debugging',
                '-a always,exit -F arch=b64 -S ptrace -F a0=0x4 -F key=code_injection',
                '-a always,exit -F arch=b32 -S ptrace -F a0=0x4 -F key=code_injection',
                '-a always,exit -F arch=b64 -S ptrace -F a0=0x5 -F key=data_injection',
                '-a always,exit -F arch=b32 -S ptrace -F a0=0x5 -F key=data_injection',
                '-a always,exit -F arch=b64 -S ptrace -F a0=0x6 -F key=register_injection',
                '-a always,exit -F arch=b32 -S ptrace -F a0=0x6 -F key=register_injection',
                '-a always,exit -F arch=b64 -S ptrace -F key=tracing',
                '-a always,exit -F arch=b32 -S ptrace -F key=tracing'
            ],
            rule_suspicious_packages => $suspicious_packages,
            order   => 15
        }

        /* Ignore current working directory records */
        basic_settings::security_audit { 'kernel-cwd':
            rules => ['-a always,exclude -F msgtype=CWD'],
            order => 1
        }
    }
}
