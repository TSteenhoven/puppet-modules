class basic_settings::io(
) {

    /* Create list of packages that is suspicious */
    $suspicious_packages = ['/usr/bin/rsync']

    /* Active multipatch */
    exec { 'multipath_cmdline':
        command => "/usr/bin/sed 's/multipath=off//g' /boot/firmware/cmdline.txt",
        onlyif  => "/usr/bin/bash -c 'if [ ! -f /boot/firmware/cmdline.txt ]; then exit 1; fi; if [ $(grep -c \'multipath=off\' /boot/firmware/cmdline.txt) -eq 1 ]; then exit 0; fi; exit 1'",
        require => Package['sed']
    }

    /* Install default development packages */
    package { ['fuse', 'logrotate', 'multipath-tools-boot', 'pbzip2', 'pigz', 'rsync', 'unzip', 'xz-utils']:
        ensure  => installed,
        require => Exec['multipath_cmdline']
    }

    /* Remove package for connection with Windows environment / device  */
    package { ['ntfs-3g', 'smbclient']:
        ensure  => purged
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
        source  => 'puppet:///modules/basic_settings/io/multipath.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        notify  => Service['multipathd']
    }

    if (defined(Package['systemd'])) {
        /* Reload systemd deamon */
        exec { 'io_systemd_daemon_reload':
            command         => '/usr/bin/systemctl daemon-reload',
            refreshonly     => true,
            require         => Package['systemd']
        }

        /* Create drop in for systemd journal service */
        basic_settings::systemd_drop_in { 'journald_settings':
            target_unit     => 'journald.conf',
            path            => '/etc/systemd',
            journal         => {
                'MaxLevelSyslog'    => 'warning',
                'MaxLevelConsole'   => 'warning'
            },
            daemon_reload   => 'io_systemd_daemon_reload',
            require         => Package['systemd']
        }
    }

    /* Setup audit rules */
    if (defined(Package['auditd'])) {
        basic_settings::security_audit { 'logrotate':
            rules => ['-a always,exclude -F auid=unset -F exe=/usr/sbin/logrotate'],
            order => '01'
        }
        basic_settings::security_audit { 'io':
            rule_suspicious_packages    => $suspicious_packages
        }
    }
}
