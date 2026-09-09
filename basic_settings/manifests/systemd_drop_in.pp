# @summary Manages a systemd drop-in file for a unit or daemon configuration.
#
# lint:ignore:140chars
# This defined type writes `<path>/<target_unit>.d/<title>.conf` from the shared drop-in template, creates the drop-in directory when needed, and notifies the selected daemon-reload exec. It is used throughout the repository to add service ordering, failure hooks, and hardening settings without replacing vendor units.
# lint:endignore
#
# @example Add a service hardening drop-in
#   basic_settings::systemd_drop_in { 'example_settings':
#     target_unit => 'example.service',
#     service     => { 'PrivateTmp' => 'true' },
#   }
#
# @param target_unit
#   Final unit or daemon configuration filename that receives the drop-in.
#
# @param daemon_reload
#   Exec resource title notified after the drop-in changes.
#
# @param ensure
#   Controls whether the drop-in file is present or absent.
#
# @param journal
#   Key/value settings rendered into a journald configuration drop-in section.
#
# @param mount
#   Key/value settings rendered into the `[Mount]` section.
#
# @param path
#   Base directory containing the target unit or daemon configuration. The default is `/etc/systemd/system`.
#
# @param resolve
#   Key/value settings rendered into a resolved configuration drop-in section.
#
# @param service
#   Key/value settings rendered into the `[Service]` section.
#
# @param socket
#   Key/value settings rendered into the `[Socket]` section.
#
# @param timer
#   Key/value settings rendered into the `[Timer]` section.
#
# @param unit
#   Key/value settings rendered into the `[Unit]` section.
#
# @api public
define basic_settings::systemd_drop_in (
  String                    $target_unit,
  String                    $daemon_reload = 'systemd_daemon_reload',
  Enum['present', 'absent'] $ensure        = present,
  Hash                      $journal       = {},
  Hash                      $mount         = {},
  String                    $path          = '/etc/systemd/system',
  Hash                      $resolve       = {},
  Hash                      $service       = {},
  Hash                      $socket        = {},
  Hash                      $timer         = {},
  Hash                      $unit          = {},
) {
  # Check if systemd package is not defined
  if (!defined(Package['systemd'])) {
    package { 'systemd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Check if this dir is not already managed by puppet
  if (!defined(File["${path}/${target_unit}.d"])) {
    file { "${path}/${target_unit}.d":
      ensure  => directory,
      recurse => true,
      force   => true,
      purge   => true,
      owner   => 'root',
      group   => 'root',
      mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
      require => Package['systemd'],
    }
  }

  # Check if target is not custom service
  if ($path == '/etc/systemd/system'
    and !defined(File["/usr/lib/systemd/system/${target_unit}"])
  and !defined(File["/etc/systemd/system/${target_unit}"])) {
    file { "/usr/lib/systemd/system/${target_unit}":
      ensure  => file,
      replace => false,
      owner   => 'root',
      group   => 'root',
      mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
      require => Package['systemd'],
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
