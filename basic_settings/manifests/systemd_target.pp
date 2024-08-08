
define basic_settings::systemd_target(
    $description,
    $parent_targets,
    $ensure                 = present,
    $stronger_requirements  = true,
    $allow_isolate          = false,
    $unit                   = {},
    $install                = {}
) {

    file { "/etc/systemd/system/${title}.target":
        ensure  => $ensure,
        content => template('basic_settings/systemd/target'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
        notify  => Exec['systemd_daemon_reload'],
        require => Package['systemd']
    }
}
