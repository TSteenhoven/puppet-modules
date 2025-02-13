define basic_settings::systemd_timer (
  String                    $description,
  Enum['present','absent']  $ensure         = present,
  Hash                      $unit           = {},
  Hash                      $timer          = {},
  Hash                      $install        = {
    'WantedBy'  => 'timers.target',
  },
  String                    $daemon_reload  = 'systemd_daemon_reload'
) {
  # Create timer file
  file { "/etc/systemd/system/${title}.timer":
    ensure  => $ensure,
    content => template('basic_settings/systemd/timer'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
    notify  => Exec[$daemon_reload],
    require => Package['systemd'],
  }

  # Enable timer
  service { "${title}.timer":
    ensure  => true,
    enable  => true,
    require => File["/etc/systemd/system/${title}.timer"],
  }
}
