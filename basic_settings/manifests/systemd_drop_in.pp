define basic_settings::systemd_drop_in(
    $target_unit,
    $daemon_reload      = 'systemd_daemon_reload',
    $ensure             = present,
    $journal            = {},
    $mount              = {},
    $path               = '/etc/systemd/system',
    $resolve            = {},
    $service            = {},
    $socket             = {},
    $timer              = {},
    $unit               = {}
) {

    /* Check if this dir is not already managed by puppet */
    if (!defined(File["${path}/${target_unit}.d"])) {
        file { "${path}/${target_unit}.d":
            ensure  => directory,
            recurse => true,
            force   => true,
            purge   => true,
            owner   => 'root',
            group   => 'root',
            mode    => '0700',
        }
    }

    /* Check if target is not custom service */
    if ($target_unit == 'nginx.service' and $path == '/etc/systemd/system' and !defined(File["/etc/systemd/system/${target_unit}"])) {
        file { "/usr/lib/systemd/system/${target_unit}":
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            mode    => '0700'
        }
    }

    /* Create configuration */
    file { "${path}/${target_unit}.d/${title}.conf":
        ensure  => $ensure,
        content => template('basic_settings/systemd/drop_in'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec["${daemon_reload}"],
        require => Package['systemd']
    }
}
