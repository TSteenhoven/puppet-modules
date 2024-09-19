define basic_settings::systemd_service (
  String                    $description,
  Enum['present','absent']  $ensure         = present,
  Hash                      $unit           = {},
  Hash                      $service        = {},
  Hash                      $install        = {
    'WantedBy'  => 'multi-user.target',
  },
  String $daemon_reload  = 'systemd_daemon_reload'
) {
  file { "/etc/systemd/system/${title}.service":
    ensure  => $ensure,
    content => template('basic_settings/systemd/service'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
    notify  => Exec[$daemon_reload],
    require => Package['systemd'],
  }
}
