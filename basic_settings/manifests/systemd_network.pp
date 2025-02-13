define basic_settings::systemd_network (
  String                    $daemon_reload  = 'systemd_daemon_reload',
  Enum['present','absent']  $ensure         = present,
  String                    $interface      = 'ens*',
  Hash                      $ipv6_accept_ra = {},
  Hash                      $network        = {},
) {
  file { "/etc/systemd/network/${title}.network":
    ensure  => $ensure,
    content => template('basic_settings/systemd/network'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
    notify  => Exec[$daemon_reload],
    require => Package['systemd'],
  }
}
