# @summary Manages one Naemon host configuration file.
#
# lint:ignore:140chars
# This defined type writes a host configuration file below the directory prepared by the `naemon` class and notifies the `naemon` service. It must be used only after the `naemon` class has resolved package paths and webserver ownership.
# lint:endignore
#
# @example Add a Naemon host with custom checks
#   naemon::host { 'web01':
#     address => '192.0.2.10',
#     checks  => {
#       'ssh' => { passive_checks_enabled => true },
#     },
#   }
#
# @param address
#   Address rendered into the host definition.
#
# @param checks
#   Hash of service checks rendered by the host template.
#
# @param ensure
#   Controls whether the host configuration is present or absent.
#
# @param friendly
#   Optional display name for the host.
#
# @api public
define naemon::host (
  String                    $address,
  Hash                      $checks   = {},
  Enum['present', 'absent'] $ensure   = present,
  Optional[String]          $friendly = undef,
) {
  if (defined(Class['naemon'])) {
    # Create host file
    file { "${naemon::config_dir}/20-host-${name}.cfg":
      ensure  => $ensure,
      owner   => $naemon::webserver_uid,
      group   => $naemon::webserver_gid,
      mode    => '0600',
      content => template('naemon/host.cfg'),
      notify  => Service['naemon'],
      require => File[$naemon::config_dir],
    }
  } else {
    fail('The naemon class must be included before using the naemon::host defined type.')
  }
}
