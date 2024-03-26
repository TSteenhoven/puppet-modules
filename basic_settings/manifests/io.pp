class basic_settings::io(
    $samba_client_enable = false
) {

    /* Install default development packages */
    package { 'multipath-tools-boot':
        ensure  => installed
    }

    /* Check if samba client is needed */
    if ($samba_client_enable)  {
        package { 'smbclient':
            ensure  => installed
        }
    } else {
        package { 'smbclient':
            ensure  => purged
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
        source  => 'puppet:///modules/basic_settings/io/multipath.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        notify  => Service['multipathd']
    }
}
