define basic_settings::systemd_drop_in(
    String $target_unit,
    Optional[String]                    $daemon_reload      = 'systemd_daemon_reload',
    Optional[Enum['present','absent']]  $ensure             = present,
    Optional[Hash]                      $journal            = {},
    Optional[Hash]                      $mount              = {},
    Optional[String]                    $path               = '/etc/systemd/system',
    Optional[Hash]                      $resolve            = {},
    Optional[Hash]                      $service            = {},
    Optional[Hash]                      $socket             = {},
    Optional[Hash]                      $timer              = {},
    Optional[Hash]                      $unit               = {}
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
            mode    => '0740', # See issue https://github.com/systemd/systemd/issues/770
        }
    }

    /* Check if target is not custom service */
    if ($path == '/etc/systemd/system'
        and !defined(File["/usr/lib/systemd/system/${target_unit}"])
        and !defined(File["/etc/systemd/system/${target_unit}"])) {

        file { "/usr/lib/systemd/system/${target_unit}":
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            mode    => '0640' # See issue https://github.com/systemd/systemd/issues/770
        }
    }

    /* Create configuration */
    file { "${path}/${target_unit}.d/${title}.conf":
        ensure  => $ensure,
        content => template('basic_settings/systemd/drop_in'),
        owner   => 'root',
        group   => 'root',
        mode    => '0640', # See issue https://github.com/systemd/systemd/issues/770
        notify  => Exec["${daemon_reload}"],
        require => Package['systemd']
    }
}
