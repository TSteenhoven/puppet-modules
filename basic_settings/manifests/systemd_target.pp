# @summary Manages a generated systemd target unit.
#
# lint:ignore:140chars
# This defined type writes `/etc/systemd/system/<title>.target` from the shared template. It is the building block for the target ladder used by service modules to bind workloads into predictable startup phases.
# lint:endignore
#
# @example Create an isolatable target
#   basic_settings::systemd_target { 'core-services':
#     description    => 'Services',
#     parent_targets => ['multi-user'],
#     allow_isolate  => true,
#   }
#
# @param description
#   Human-readable target description rendered into the unit.
#
# @param parent_targets
#   Parent target names used to render ordering and install relationships.
#
# @param allow_isolate
#   Controls whether the target may be isolated with `systemctl isolate`.
#
# @param ensure
#   Controls whether the generated target unit is present or absent.
#
# @param install
#   Key/value settings rendered into the `[Install]` section.
#
# @param stronger_requirements
#   Controls whether the template uses stronger dependency semantics for parent target relationships.
#
# @param unit
#   Additional key/value settings rendered into the `[Unit]` section.
#
# @api public
define basic_settings::systemd_target (
  String                    $description,
  Array                     $parent_targets,
  Boolean                   $allow_isolate         = false,
  Enum['present', 'absent'] $ensure                = present,
  Hash                      $install               = {},
  Boolean                   $stronger_requirements = true,
  Hash                      $unit                  = {},
) {
  # Check if systemd package is not defined
  if (!defined(Package['systemd'])) {
    package { 'systemd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Create systemd target file
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
