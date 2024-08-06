define basic_settings::systemd_service(
        $ensure         = present,
        $description,
        $unit           = {},
        $service        = {},
        $install        = {
            'WantedBy'  => 'multi-user.target'
        },
        $daemon_reload  = 'systemd_daemon_reload'
    ) {

    file { "/etc/systemd/system/${title}.service":
        ensure  => $ensure,
        content => template('basic_settings/systemd/service'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec["${daemon_reload}"],
        require => Package['systemd']
    }
}
