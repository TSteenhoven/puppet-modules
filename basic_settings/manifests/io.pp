class basic_settings::io(
) {

    /* Create list of packages that is suspicious */
    $suspicious_packages = ['/usr/bin/rsync']

    /* Install default development packages */
    package { ['fuse', 'logrotate', 'multipath-tools-boot', 'pbzip2', 'pigz', 'rsync', 'unzip', 'xz-utils']:
        ensure  => installed
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
