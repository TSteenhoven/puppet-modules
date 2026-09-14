# @summary Manages a systemd-networkd `.network` file.
#
# This defined type writes `/etc/systemd/network/<title>.network` from the shared template and notifies a daemon-reload
# exec. It is used for repository-managed DHCP and router-advertisement policy that complements the network module.
#
# @example Disable DHCP for matching interfaces
#   basic_settings::systemd_network { '90-dhcpc':
#     interface => 'ens*',
#     network   => { 'DHCP' => 'no' },
#   }
#
# @param daemon_reload
#   Exec resource title notified after the network file changes.
#
# @param ensure
#   Controls whether the network file is present or absent.
#
# @param interface
#   Match expression rendered for the networkd interface name.
#
# @param ipv6_accept_ra
#   Key/value settings rendered into the `[IPv6AcceptRA]` section.
#
# @param network
#   Key/value settings rendered into the `[Network]` section.
#
# @api public
define basic_settings::systemd_network (
  String                    $daemon_reload  = 'systemd_daemon_reload',
  Enum['present', 'absent'] $ensure         = present,
  String                    $interface      = 'ens*',
  Hash                      $ipv6_accept_ra = {},
  Hash                      $network        = {},
) {
  # Check if systemd package is not defined
  if (!defined(Package['systemd'])) {
    package { 'systemd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Create netwotk config
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
