define basic_settings::systemd_service(
        $ensure         = present,
        $description,
        $unit           = {},
        $service        = {},
        $install        = {}
    ) {

    file { "/etc/systemd/system/${title}.service":
        ensure  => $ensure,
        content => template('basic_settings/systemd/service'),
        mode    => '0644',
        notify  => Exec['systemd_daemon_reload']
    }
}
