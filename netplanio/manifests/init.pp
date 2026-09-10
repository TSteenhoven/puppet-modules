# @summary Installs netplan.io and prepares shared netplan defaults.
#
# lint:ignore:140chars
# This class ensures the netplan package is available, derives DHCP, IPv6 router advertisement, IP-version, and renderer defaults from `basic_settings` when present, removes the cloud-init netplan file, exposes a refresh-only `netplan apply` exec, and adds audit rules for `/etc/netplan`.
# lint:endignore
#
# @example Prepare netplan management
#   include netplanio
#
# @api public
class netplanio (
) {
  # Check if systemd is not installed
  if (!defined(Package['netplan.io'])) {
    # Install netplan.io package
    package { 'netplan.io':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Check if we have network class
  if (!defined(Class['basic_settings::network'])) {
    # Default standalone Netplan configuration to DHCP.
    $dhcp_enable = true

    # Inherit IP policy from the kernel class when no central network class owns it.
    if (defined(Class['basic_settings::kernel'])) {
      # Inherit IP-family and router-advertisement policy from the kernel class.
      $ip_version = $basic_settings::kernel::ip_version
      $ip_ra_enable = ($basic_settings::kernel::ip_version_v6 and $basic_settings::kernel::ip_ra_enable)
    } else {
      # Default to both IP families without accepting router advertisements when no kernel policy exists.
      $ip_version = 'all'
      $ip_ra_enable = false
    }
  } else {
    # Reuse the network class's DHCP, router-advertisement, and IP-family policy.
    $dhcp_enable = $basic_settings::network::dhcp_enable
    $ip_ra_enable = $basic_settings::network::ip_ra_enable
    $ip_version = $basic_settings::network::ip_version
  }

  # Check if we have systemd
  if (defined(Package['systemd'])) {
    # Select networkd when systemd is managed on the host.
    $renderer = 'networkd'
  } else {
    # Leave renderer selection to Netplan when systemd is unavailable.
    $renderer = undef
  }

  # Command for triggering netplan config
  exec { 'netplanio_apply':
    command     => '/usr/sbin/netplan apply',
    refreshonly => true,
    require     => Package['netplan.io'],
  }

  # Remove cloud init file
  file { '/etc/netplan/50-cloud-init.yaml':
    ensure  => absent,
    notify  => Exec['netplanio_apply'],
    require => Package['netplan.io'],
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'netplanio':
      rules => [
        '-a always,exit -F arch=b32 -F dir=/etc/netplan -F perm=wa -F key=netplanio',
        '-a always,exit -F arch=b64 -F dir=/etc/netplan -F perm=wa -F key=netplanio',
      ],
      order => 20,
    }
  }
}
