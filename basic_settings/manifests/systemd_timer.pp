define basic_settings::systemd_timer(
        $ensure         = present,
        $description,
        $unit           = {},
        $timer          = {},
        $install        = {
            'WantedBy'  => 'timers.target'
        }
    ) {

    /* Create timer file */
    file { "/etc/systemd/system/${title}.timer":
        ensure  => $ensure,
        content => template('basic_settings/systemd/timer'),
        mode    => '0644',
        notify  => Exec['systemd_daemon_reload']
    }

    /* Enable timer */
    service {  "${title}.timer":
        ensure  => true,
        enable  => true,
        require => File["/etc/systemd/system/${title}.timer"]
    }
}
