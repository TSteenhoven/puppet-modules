define basic_settings::systemd_timer(
        $ensure         = present,
        $description,
        $unit           = {},
        $timer          = {},
        $install        = {
            'WantedBy'  => 'timers.target'
        }
    ) {

    file { "/etc/systemd/system/${title}.timer":
        ensure  => $ensure,
        content => template('basic_settings/systemd/timer'),
        mode    => '0644',
        notify  => Exec['systemd_daemon_reload']
    }
}
