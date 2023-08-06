define basic_settings::systemd_drop_in(
    $target_unit,
    $ensure         = present,
    $unit           = {},
    $service        = {},
    $mount          = {},
    $timer          = {}
) {

    /* Check if this dir is not already managed by puppet */
    if (!defined(File["/etc/systemd/system/${target_unit}.d"])) {
        file { "/etc/systemd/system/${target_unit}.d":
            ensure  => directory,
            recurse => true,
            force   => true,
            purge   => true,
            mode    => '0755'
        }
    }

    /* Reload systemd deamon */
    if (!defined(Exec['systemd_drop_in_daemon_reload']])) {
        exec { 'systemd_drop_in_daemon_reload':
            command => "systemctl daemon-reload",
            refreshonly => true,
            require => Package['systemd']
        }
    }

    /* Create configuration */
    file { "/etc/systemd/system/${target_unit}.d/${title}.conf":
        ensure  => $ensure,
        content => template('basic_settings/systemnd_drop_in'),
        mode    => '0644',
        notify  => Exec['systemd_drop_in_daemon_reload']
    }
}
