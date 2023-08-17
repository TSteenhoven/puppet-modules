define basic_settings::systemd_drop_in(
    $target_unit,
    $ensure             = present,
    $unit               = {},
    $service            = {},
    $mount              = {},
    $timer              = {},
    $daemon_reload      = 'systemd_daemon_reload'
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

    /* Create configuration */
    file { "/etc/systemd/system/${target_unit}.d/${title}.conf":
        ensure  => $ensure,
        content => template('basic_settings/systemd/drop_in'),
        mode    => '0644',
        notify  => Exec["${daemon_reload}"]
    }
}
