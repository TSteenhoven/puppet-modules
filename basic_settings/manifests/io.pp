class basic_settings::io(

) {

    /* Install default development packages */
    package { 'multipath-tools-boot':
        ensure  => installed
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
