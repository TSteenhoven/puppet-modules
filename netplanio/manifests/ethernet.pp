# @summary Manages one netplan ethernet YAML file.
#
# This defined type renders `/etc/netplan/<title>.yaml` for an ethernet interface, inheriting DHCP and IP-version
# defaults from the `netplanio` class unless explicitly overridden. Changes notify the shared `netplan apply` exec.
#
# @example Configure a static ethernet interface
#   netplanio::ethernet { 'ens18':
#     addresses   => ['192.0.2.10/24'],
#     dhcp_enable => false,
#     routes      => { 'default' => { 'via' => '192.0.2.1' } },
#   }
#
# @param addresses
#   Optional list of addresses rendered into the interface configuration.
#
# @param dhcp_enable
#   Optional DHCP override. `undef` inherits the class-level default.
#
# @param ensure
#   Controls whether the netplan file is present or absent.
#
# @param interface
#   Interface name rendered into the YAML. `undef` uses the resource title.
#
# @param ip_version
#   Optional IP-version override. `undef` inherits the class-level default.
#
# @param nameservers
#   Optional nameserver hash rendered into the YAML.
#
# @param optional
#   Sets the netplan `optional` flag for the interface.
#
# @param routes
#   Optional route hash keyed by destination. Every destination maps to a hash containing at least `via`, for example
#   `{ 'default' => { 'via' => '192.0.2.1' } }`.
#
# @api public
define netplanio::ethernet (
  Optional[Array]           $addresses   = undef,
  Optional[Boolean]         $dhcp_enable = undef,
  Enum['present', 'absent'] $ensure      = present,
  Optional[String]          $interface   = undef,
  Optional[String]          $ip_version  = undef,
  Optional[Hash]            $nameservers = undef,
  Boolean                   $optional    = false,
  Optional[Hash]            $routes      = undef,
) {
  # Require the Netplan parent before contributing ethernet configuration.
  if (defined(Class['netplanio'])) {
    # Resolve the interface settings before rendering this ethernet entry.
    if ($ensure) {
      # Get interface
      if ($interface == undef) {
        # Use the resource title as the default interface name.
        $interface_correct = $name
      } else {
        # Preserve the caller's explicit interface name.
        $interface_correct = $interface
      }

      # Try to get dhcp value
      if ($dhcp_enable == undef) {
        # Inherit the default DHCP setting from the Netplan class.
        $dhcpc_correct = $netplanio::dhcp_enable
      } else {
        # Preserve the caller's DHCP setting for this interface.
        $dhcpc_correct = $dhcp_enable
      }

      # Get IP versions
      if ($ip_version == undef) {
        # Inherit the default IP-family selection from the Netplan class.
        $ip_version_correct = $netplanio::ip_version
      } else {
        # Preserve the caller's IP-family selection for this interface.
        $ip_version_correct = $ip_version
      }

      # Set IP values
      case $ip_version_correct {
        '4': {
          # Limit generated network settings to IPv4.
          $ip_version_v4 = true
          $ip_version_v6 = false
        }
        default: {
          # Generate settings for both IPv4 and IPv6.
          $ip_version_v4 = true
          $ip_version_v6 = true
        }
      }

      # Try to get IP RA value
      if ($dhcpc_correct and $ip_version_v6) {
        # Apply the shared router-advertisement policy when DHCP and IPv6 are enabled.
        $ip_ra_enable = $netplanio::ip_ra_enable
      } else {
        # Disable router advertisements when DHCP or IPv6 is unavailable.
        $ip_ra_enable = false
      }

      # Convert boolean to string
      $dhcpc_string = bool2str($dhcpc_correct, 'true', 'false')
      $ip_ra_string = bool2str($ip_ra_enable, 'true', 'false')

      # Set values
      $renderer = $netplanio::renderer

      # Config file
      file { "/etc/netplan/${name}.yaml":
        ensure  => file,
        content => template('netplanio/ethernet.yaml'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec['netplanio_apply'],
        require => Package['netplan.io'],
      }
    } else {
      # Remove config
      file { "/etc/netplan/${name}.yaml":
        ensure => absent,
      }
    }
  } else {
    fail('The netplanio class must be included before using the netplanio::ethernet defined type.')
  }
}
