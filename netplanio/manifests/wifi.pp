# @summary Manages one netplan WiFi YAML file.
#
# lint:ignore:140chars
# This defined type renders `/etc/netplan/<title>.yaml` for a WiFi interface, installs `wpasupplicant` when needed, stores generated WiFi configuration as sensitive content, and disables runtime power management for the interface device to avoid connectivity problems.
# lint:endignore
#
# @example Configure a DHCP WiFi interface
#   netplanio::wifi { 'wlan0':
#     access_points => {
#       'ExampleSSID' => { 'password' => lookup('profile::wifi_password') },
#     },
#   }
#
# @param access_points
#   Netplan access point hash. This can contain WiFi passwords and is rendered as sensitive file content.
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
# @param optional
#   Sets the netplan `optional` flag for the interface.
#
# @api public
define netplanio::wifi (
  Hash                      $access_points,
  Optional[Array]           $addresses     = undef,
  Optional[Boolean]         $dhcp_enable   = undef,
  Enum['present', 'absent'] $ensure        = present,
  Optional[String]          $interface     = undef,
  Optional[String]          $ip_version    = undef,
  Boolean                   $optional      = false,
) {
  # Require the Netplan parent before contributing wireless configuration.
  if (defined(Class['netplanio'])) {
    # Provision wireless dependencies and configuration only for a present entry.
    if ($ensure == present) {
      # Check if wpasupplicant is not installed
      if (!defined(Package['wpasupplicant'])) {
        # Install wpasupplicant package
        package { 'wpasupplicant':
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
        }
      }

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
        content => Sensitive.new(template('netplanio/wifi.yaml')),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Exec['netplanio_apply'],
        require => Package['netplan.io'],
      }

      # Force WiFi runtime power management to "on" for stable connectivity.
      # Escape the sysfs path before writing to it from an exec command.
      $runtime_pm_file_shell = stdlib::shell_escape("/sys/class/net/${name}/device/power/control")
      exec { "netplan_${name}_runtime_pm":
        command => "/usr/bin/printf %s on > ${runtime_pm_file_shell}",
        onlyif  => "/usr/bin/test -e ${runtime_pm_file_shell} && [ \"\$(/usr/bin/cat ${runtime_pm_file_shell})\" != \"on\" ]",
      }
    } else {
      # Remove config
      file { "/etc/netplan/${name}.yaml":
        ensure => absent,
        notify => Exec['netplanio_apply'],
      }
    }
  } else {
    fail('The netplanio class must be included before using the netplanio::wifi defined type.')
  }
}
