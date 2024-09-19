define basic_settings::systemd_target (
  String                    $description,
  String                    $parent_targets,
  Enum['present','absent']  $ensure                 = present,
  Boolean                   $stronger_requirements  = true,
  Boolean                   $allow_isolate          = false,
  Hash                      $unit                   = {},
  Hash                      $install                = {}
) {
  file { "/etc/systemd/system/${title}.target":
    ensure  => $ensure,
    content => template('basic_settings/systemd/target'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
    notify  => Exec['systemd_daemon_reload'],
    require => Package['systemd'],
  }
}
