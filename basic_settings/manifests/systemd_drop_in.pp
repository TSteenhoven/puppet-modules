define basic_settings::systemd_drop_in (
  String $target_unit,
  String                    $daemon_reload      = 'systemd_daemon_reload',
  Enum['present','absent']  $ensure             = present,
  Hash                      $journal            = {},
  Hash                      $mount              = {},
  String                    $path               = '/etc/systemd/system',
  Hash                      $resolve            = {},
  Hash                      $service            = {},
  Hash                      $socket             = {},
  Hash                      $timer              = {},
  Hash                      $unit               = {}
) {
  # Check if this dir is not already managed by puppet
  if (!defined(File["${path}/${target_unit}.d"])) {
    file { "${path}/${target_unit}.d":
      ensure  => directory,
      recurse => true,
      force   => true,
      purge   => true,
      owner   => 'root',
      group   => 'root',
      mode    => '0755', # See issue https://github.com/systemd/systemd/issues/770
    }
  }

  # Check if target is not custom service
  if ($path == '/etc/systemd/system'
    and !defined(File["/usr/lib/systemd/system/${target_unit}"])
  and !defined(File["/etc/systemd/system/${target_unit}"])) {
    file { "/usr/lib/systemd/system/${target_unit}":
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644' # See issue https://github.com/systemd/systemd/issues/770
    }
  }

  # Create configuration
  file { "${path}/${target_unit}.d/${title}.conf":
    ensure  => $ensure,
    content => template('basic_settings/systemd/drop_in'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
    notify  => Exec[$daemon_reload],
    require => Package['systemd'],
  }
}
