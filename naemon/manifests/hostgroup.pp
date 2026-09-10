# @summary Manages one Naemon hostgroup configuration file.
#
# lint:ignore:140chars
# This defined type writes a hostgroup configuration file below the directory prepared by the `naemon` class and notifies the `naemon` service.
# lint:endignore
#
# @example Add a hostgroup
#   naemon::hostgroup { 'webservers':
#     description => 'Web servers',
#   }
#
# @param description
#   Optional hostgroup description. `undef` lets the template choose its default.
#
# @param ensure
#   Controls whether the hostgroup configuration is present or absent.
#
# @api public
define naemon::hostgroup (
  Optional[String]          $description = undef,
  Enum['present', 'absent'] $ensure      = present,
) {
  # Require the Naemon parent before writing a hostgroup into its configuration tree.
  if (defined(Class['naemon'])) {
    # Create host file
    file { "${naemon::config_dir}/10-hostgroup-${name}.cfg":
      ensure  => $ensure,
      owner   => $naemon::webserver_uid,
      group   => $naemon::webserver_gid,
      mode    => '0600',
      content => template('naemon/hostgroup.cfg'),
      notify  => Service['naemon'],
      require => File[$naemon::config_dir],
    }
  } else {
    fail('The naemon class must be included before using the naemon::hostgroup defined type.')
  }
}
