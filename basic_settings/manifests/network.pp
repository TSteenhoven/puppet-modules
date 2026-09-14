# @summary Manages firewall, DHCP, systemd-networkd, DNS resolver, `/etc/hosts`, LLDP, and network audit policy.
#
# This class installs the selected firewall package, removes competing firewall stacks when requested, manages DHCP
# client behavior, optional `/etc/hosts` ownership, optional netplan and wireless packages, systemd-networkd/resolved
# drop-ins, networkd-dispatcher hooks, LLDP identity, monitoring checks, and audit rules for network tooling.
# It reads kernel and monitoring state from `basic_settings` components when they are present.
#
# @example Manage the default nftables-based network profile
#   class { 'basic_settings::network':
#     firewall_package => 'nftables',
#   }
#
# @param firewall_package
#   Firewall implementation to install and manage. Valid values are `nftables`, `iptables`, and `firewalld`.
#
# @param antivirus_package
#   Optional antivirus integration name. Some firewall package combinations are adjusted for antivirus compatibility.
#
# @param capabilities
#   LLDP capabilities advertised by the host. The default is `['station']`.
#
# @param communication_name
#   Optional hostname advertised through LLDP. `undef` builds a name from the OS and environment.
#
# @param configurator_package
#   Network configuration frontend to install. `netplan.io` installs netplan; `none` purges it.
#
# @param dhcp_enable
#   Enables DHCP client configuration when `true`. When `false`, the class can still retain DHCP tooling if the
#   kernel/initramfs setup needs it.
#
# @param dns_dnssec
#   DNSSEC mode rendered into the systemd-resolved drop-in.
#
# @param dns_fallback
#   Fallback DNS server list rendered into the systemd-resolved drop-in.
#
# @param environment
#   Environment label used in LLDP descriptions. The default is `production`.
#
# @param firewall_path
#   Path to the iptables restore file used by the networkd-dispatcher hook when `firewall_package` is `iptables`.
#
# @param firewall_remove
#   Purges competing firewall packages when `true`.
#
# @param hosts_enable
#   Enables ownership of `/etc/hosts` through concat using the short hostname and `server_fdqn`.
#
# @param hosts_localhost_aliases
#   Additional host aliases appended to the `127.0.0.1 localhost` record when hosts management is enabled.
#
# @param install_options
#   Additional APT options; an empty array adds no caller options. Mandatory no-recommends and no-suggests flags are
#   appended without deduplication so they remain effective.
#
# @param interfaces
#   Interface name patterns used for systemd-networkd DHCP and router advertisement drop-ins.
#
# @param server_fdqn
#   Fully qualified host name used by generated monitoring output.
#
# @param wireless_enable
#   Installs `wpasupplicant` when `true`; purges it when `false`.
#
# @api public
class basic_settings::network (
  Enum['nftables', 'iptables', 'firewalld'] $firewall_package,
  Optional[String]                          $antivirus_package       = undef,
  Array[String]                             $capabilities            = ['station'],
  Optional[String]                          $communication_name      = undef,
  Enum['none', 'netplan.io']                $configurator_package    = 'none',
  Boolean                                   $dhcp_enable             = true,
  Enum['allow-downgrade', 'no']             $dns_dnssec              = 'allow-downgrade',
  Array                                     $dns_fallback            = [
    '8.8.8.8',
    '8.8.4.4',
    '2001:4860:4860::8888',
    '2001:4860:4860::8844',
  ],
  String                                    $environment             = 'production',
  String                                    $firewall_path           = '/etc/firewall.conf',
  Boolean                                   $firewall_remove         = true,
  Boolean                                   $hosts_enable            = false,
  Array[String[1]]                          $hosts_localhost_aliases = [],
  Array                                     $install_options         = [],
  Array                                     $interfaces              = ['eth*', 'ens*', 'wlan*'],
  String                                    $server_fdqn             = $facts['networking']['fqdn'],
  Boolean                                   $wireless_enable         = false,
) {
  # Set some default values
  $kernel_enable = defined(Class['basic_settings::kernel'])
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  $systemd_enable = defined(Package['systemd'])
  $interfaces_str = join($interfaces, ' ')

  # Get IP data
  if ($kernel_enable) {
    # Inherit the IP-family selection from the kernel configuration.
    $ip_version = $basic_settings::kernel::ip_version

    # Enable DHCPv6 only when both IPv6 and DHCP are allowed.
    if ($basic_settings::kernel::ip_version_v6 and $dhcp_enable) {
      # Allow DHCPv6 for automatic address configuration with IPv6 available.
      $ip_dhcp_v6 = true

      # Carry the kernel's router-advertisement policy into network configuration.
      if ($basic_settings::kernel::ip_ra_enable) {
        # Enable router advertisements according to the kernel's IPv6 policy.
        $ip_ra_enable = true
      } else {
        # Keep router advertisements disabled according to the kernel's IPv6 policy.
        $ip_ra_enable = false
      }
    } else {
      # Disable IPv6 autoconfiguration when either IPv6 or DHCP is unavailable.
      $ip_dhcp_v6 = false
      $ip_ra_enable = false
    }
  } else {
    # Allow both IP families when no kernel configuration selects one.
    $ip_version = 'all'

    # Use DHCP to choose standalone IPv6 autoconfiguration defaults.
    if ($dhcp_enable) {
      # Enable DHCPv6 and router advertisements for standalone automatic configuration.
      $ip_dhcp_v6 = true
      $ip_ra_enable = true
    } else {
      # Disable DHCPv6 and router advertisements without automatic address configuration.
      $ip_dhcp_v6 = false
      $ip_ra_enable = false
    }
  }

  # Get LLDP data
  $lldp_capabilities = join($capabilities, ' ')
  $lldp_platform = $facts['os']['name']
  $lldp_description = "${lldp_platform} ${environment} server"

  # Derive the advertised hostname unless a communication name was supplied.
  if ($communication_name == undef) {
    # Identify the advertised host by platform and environment.
    $communication_hostname = "${lldp_platform.downcase()}-${environment}"
  } else {
    # Normalize the supplied discovery name into a lowercase token without whitespace.
    $communication_hostname = regsubst($communication_name.downcase, '\s+', '-', 'G')
  }

  # Delegate hosts-file ownership to the dedicated hosts class while preserving the configured FQDN.
  if ($hosts_enable) {
    class { 'basic_settings::hosts':
      localhost_aliases => $hosts_localhost_aliases,
      server_fdqn       => $server_fdqn,
    }
  }

  # Default suspicious packages
  $default_packages = [
    '/usr/bin/ip',
    '/usr/bin/mtr',
    '/usr/bin/nc',
    '/usr/bin/netcat',
    '/usr/bin/ping',
    '/usr/bin/ping4',
    '/usr/bin/ping6',
    '/usr/bin/tcptraceroute',
    '/usr/bin/tcpdump',
    '/usr/bin/telnet',
    '/usr/sbin/arp',
    '/usr/sbin/route',
    '/usr/sbin/traceroute',
  ]
  $default_packages_root = [
    '/usr/bin/ip',
    '/usr/bin/ping',
    '/usr/bin/ping4',
    '/usr/bin/ping6',
  ]

  # Based on firewall package do special commands
  case $firewall_package {
    'nftables': {
      # Leave legacy firewall restore commands empty for this firewall backend.
      $firewall_command = ''

      # Remove competing firewall implementations only when migration cleanup is requested.
      if ($firewall_remove) {
        package { ['iptables', 'firewalld']:
          ensure => purged,
        }

        # Remove unnecessary files
        file { '/etc/firewalld':
          ensure  => absent,
          recurse => true,
          force   => true,
          require => Package['firewalld'],
        }
      }

      # Create list of packages that is suspicious
      $suspicious_packages = flatten($default_packages, ['/usr/sbin/nft'])
      $suspicious_packages_root = flatten($default_packages_root, ['/usr/sbin/nft'])
    }
    'iptables': {
      # Restore the configured rules through the selected iptables backend.
      $firewall_command = "iptables-restore < ${firewall_path}"

      # Remove competing firewall implementations only when migration cleanup is requested.
      if ($firewall_remove) {
        package { ['nftables', 'firewalld']:
          ensure => purged,
        }
      }

      # Create list of packages that is suspicious
      $suspicious_packages = flatten($default_packages, ['/usr/sbin/iptables'])
      $suspicious_packages_root = $default_packages_root
    }
    'firewalld': {
      # Leave legacy firewall restore commands empty for this firewall backend.
      $firewall_command = ''
      case $antivirus_package {
        'eset': {
          # Remove the old iptables package only when firewall cleanup is requested.
          if ($firewall_remove) {
            package { 'iptables':
              ensure => purged,
            }
          }

          # Keep nftables available for the ESET firewall even when the previous firewall package is removed.
          package { 'nftables':
            ensure          => installed,
            install_options => ['--no-install-recommends', '--no-install-suggests'],
          }

          # Create list of packages that is suspicious
          $suspicious_packages = flatten($default_packages, ['/usr/bin/firewall-cmd', '/usr/sbin/nft'])
          $suspicious_packages_root = $default_packages_root
        }
        default:  {
          # Remove competing firewall implementations only when migration cleanup is requested.
          if ($firewall_remove) {
            package { ['nftables', 'iptables']:
              ensure => purged,
            }
          }

          # Create list of packages that is suspicious
          $suspicious_packages = flatten($default_packages, ['/usr/bin/firewall-cmd'])
          $suspicious_packages_root = $default_packages_root
        }
      }
    }
    default: {
      # Other firewall selections do not need these implementation-specific resources.
    }
  }

  # Install package
  # Keep policy flags last even when caller options contain duplicate or conflicting flags.
  package { $firewall_package:
    ensure          => installed,
    install_options => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
  }

  # Remove unnecessary packages
  package { ['ifupdown', 'iw', 'netcat-traditional', 'wireless-tools']:
    ensure => purged,
  }

  # Install package
  package { [
      'dnsutils',
      'ethtool',
      'iputils-ping',
      'lldpd',
      'mtr-tiny',
      'netcat-openbsd',
      'net-tools',
      'telnet',
      'tcpdump',
      'iproute2',
      'tcptraceroute',
      'traceroute',
    ]:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['ifupdown'],
  }

  # Check if dhcpc is needed on this server
  $dhcp_state = ($dhcp_enable or ($kernel_enable and $basic_settings::kernel::ram_disk_package == 'initramfs'))
  if ($dhcp_state) {
    # Install dhcpcd-base
    if (!defined(Package['dhcpcd-base'])) {
      package { 'dhcpcd-base':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Install dhcpcd
    package { ['dhcpcd']:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => [Package['dhcpcd-base', 'ifupdown']],
    }

    # Enable dhcpcd service
    service { 'dhcpcd':
      ensure  => true,
      enable  => true,
      require => Package['dhcpcd'],
    }

    # Setup DHCP config
    if ($dhcp_enable) {
      # DHCP is enabled
      file { '/etc/dhcpcd.conf':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        content => template('basic_settings/network/dhcpcd.conf'),
        notify  => Service['dhcpcd'],
      }
    } elsif ($kernel_enable) {
      # DHCP is disabled, but we need dhcpd package because kernel package
      file { '/etc/dhcpcd.conf':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        content => "# Managed by puppet\ndenyinterfaces *\n",
        notify  => Service['dhcpcd'],
      }
    }
  } else {
    # Purge dhcpcd
    package { ['dhcpcd', 'dhcpcd-base']:
      ensure  => purged,
      require => Package['ifupdown'],
    }
  }

  # Try to get network configurator
  case $configurator_package {
    'netplan.io': {
      package { 'netplan.io':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }
    default: {
      package { 'netplan.io':
        ensure => purged,
      }
    }
  }

  # Check if we need to install wireless packages
  if ($wireless_enable) {
    package { 'wpasupplicant':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    package { 'wpasupplicant':
      ensure => purged,
    }
  }

  # Reload systemd deamon
  if (defined(Class['basic_settings::systemd']) or $monitoring_enable) {
    exec { 'network_firewall_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }
  }

  # Check which firewall we have
  if ($firewall_package == 'nftables' or $firewall_package == 'firewalld') {
    # Start service 
    service { $firewall_package:
      ensure  => running,
      enable  => true,
      require => Package[$firewall_package],
    }

    # Add firewall checks and failure notifications only with monitoring integration.
    if ($monitoring_enable) {
      # Create service check
      if ($basic_settings::monitoring::package != 'none') {
        # Use a service check for firewalld and the configuration-aware check for nftables.
        if ($firewall_package != 'nftables') {
          basic_settings::monitoring_service { 'firewall':
            services => [$firewall_package],
          }
        } else {
          basic_settings::monitoring_custom { 'firewall':
            content => template("basic_settings/monitoring/check_${firewall_package}"),
          }
        }
      }

      # Attach firewall failure notifications only when systemd integration is available.
      if ($systemd_enable) {
        # Create drop in for firewall service
        basic_settings::systemd_drop_in { "${firewall_package}_notify_failed":
          target_unit   => "${firewall_package}.service",
          unit          => {
            'OnFailure' => 'notify-failed@%i.service',
          },
          daemon_reload => 'network_firewall_systemd_daemon_reload',
          require       => Package[$firewall_package],
        }
      }
    }
  }

  # Create RX buffer script
  file { '/usr/local/sbin/rxbuffer':
    ensure => file,
    source => 'puppet:///modules/basic_settings/network/rxbuffer',
    owner  => 'root',
    group  => 'root',
    mode   => '0755', # High important
  }

  # Apply DHCP and router-advertisement policy through managed systemd network files.
  if ($systemd_enable) {
    # If DHCP is disabled, force system not to use DHCP
    if ($interfaces_str != '' and !$dhcp_enable) {
      basic_settings::systemd_network { '90-dhcpc':
        interface     => $interfaces_str,
        network       => {
          'DHCP' => 'no',
        },
        daemon_reload => 'network_firewall_systemd_daemon_reload',
      }
    } else {
      basic_settings::systemd_network { '90-dhcpc':
        ensure        => absent,
        daemon_reload => 'network_firewall_systemd_daemon_reload',
      }
    }

    # Setup default router advertisement settings
    if ($interfaces_str != '') {
      # Configure learned IPv6 prefixes when router advertisements are allowed.
      if ($ip_ra_enable) {
        # Translate the kernel's prefix-learning policy into a networkd boolean.
        $ip_learn_prefix = bool2str($basic_settings::kernel::ip_ra_learn_prefix, 'yes', 'no')
        basic_settings::systemd_network { '90-router-advertisement':
          interface      => $interfaces_str,
          ipv6_accept_ra => {
            'UseAutonomousPrefix' => $ip_learn_prefix,
            'UseOnLinkPrefix'     => $ip_learn_prefix,
          },
          network        => {
            'IPv6AcceptRA'        => 'yes',
            'LinkLocalAddressing' => 'ipv6',
          },
          daemon_reload  => 'network_firewall_systemd_daemon_reload',
        }
      } else {
        basic_settings::systemd_network { '90-router-advertisement':
          interface     => $interfaces_str,
          network       => {
            'IPv6AcceptRA'        => 'no',
            'LinkLocalAddressing' => 'no',
          },
          daemon_reload => 'network_firewall_systemd_daemon_reload',
        }
      }
    } else {
      basic_settings::systemd_network { '90-router-advertisement':
        ensure        => absent,
        daemon_reload => 'network_firewall_systemd_daemon_reload',
      }
    }

    # Set networkd rules
    $networkd_rules = [
      '-a always,exit -F arch=b32 -F path=/etc/networkd-dispatcher -F perm=wa -F key=network',
      '-a always,exit -F arch=b64 -F path=/etc/networkd-dispatcher -F perm=wa -F key=network',
    ]

    # Install package
    package { 'networkd-dispatcher':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['ifupdown'],
    }

    # Set script that's set the firewall
    if ($firewall_command != '') {
      file { 'firewall_networkd_dispatcher':
        ensure  => file,
        path    => "/etc/networkd-dispatcher/routable.d/${firewall_package}",
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        content => "#!/bin/sh\n\ntest -r ${firewall_path} && ${firewall_command}\n\nexit 0\n",
        require => Package[$firewall_package],
      }
    } else {
      # Remove firewall package
      case $firewall_package {
        'nftables', 'firewalld': {
          file { 'firewall_networkd_dispatcher':
            ensure  => absent,
            path    => '/etc/networkd-dispatcher/routable.d/iptables',
            require => Package[$firewall_package],
          }
        }
        default: {
          # Other firewall selections do not need these implementation-specific resources.
        }
      }
    }

    # Create RX buffer script
    file { '/etc/networkd-dispatcher/routable.d/rxbuffer':
      ensure  => file,
      content => template('basic_settings/network/rxbuffer'),
      owner   => 'root',
      group   => 'root',
      mode    => '0755', # High important,
      require => [Package['networkd-dispatcher'], File['/usr/local/sbin/rxbuffer']],
    }

    # Check if systemd resolved package exists
    case $facts['os']['name'] {
      'Ubuntu': {
        # Select the separate systemd-resolved package for Ubuntu 24.04.
        $os_version = $facts['os']['release']['major']
        if ($os_version == '24.04') {
          # Manage the separate resolver package on Ubuntu 24.04.
          $systemd_resolved_package = true
        } else {
          # Omit the separate resolver package on the other Ubuntu release paths.
          $systemd_resolved_package = false
        }
      }
      default: {
        # Manage the separate resolver package on the default distribution path.
        $systemd_resolved_package = true
      }
    }

    # Set settings
    $systemd_resolved_settings = {
      'Cache'         => 'yes',
      'DNSOverTLS'    => 'opportunistic',
      'DNSSEC'        => $dns_dnssec,
      'FallbackDNS'   => join($dns_fallback, ' '),
      'LLMNR'         => 'no',
      'MulticastDNS'  => 'no',
      'ReadEtcHosts'  => 'yes',
    }

    # Check if we need to install a systemd resolved package or if it's all built-in
    if ($systemd_resolved_package) {
      # Keep policy flags last even when caller options contain duplicate or conflicting flags.
      package { 'systemd-resolved':
        ensure          => installed,
        install_options => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
      }

      # Ensure that networkd services is always running
      service { ['systemd-networkd.service', 'systemd-resolved.service', 'networkd-dispatcher.service']:
        ensure  => running,
        enable  => true,
        require => [Package['networkd-dispatcher', 'systemd', 'systemd-resolved']],
      }

      # Create drop in for systemd resolved service
      basic_settings::systemd_drop_in { 'resolved_settings':
        target_unit   => 'resolved.conf',
        path          => '/etc/systemd',
        resolve       => $systemd_resolved_settings,
        daemon_reload => 'network_firewall_systemd_daemon_reload',
        require       => Package['systemd-resolved'],
      }
    } else {
      # Ensure that networkd services is always running
      service { ['systemd-networkd.service', 'systemd-resolved.service', 'networkd-dispatcher.service']:
        ensure  => running,
        enable  => true,
        require => [Package['networkd-dispatcher', 'systemd']],
      }

      # Create drop in for systemd resolved service
      basic_settings::systemd_drop_in { 'resolved_settings':
        target_unit   => 'resolved.conf',
        path          => '/etc/systemd',
        resolve       => $systemd_resolved_settings,
        daemon_reload => 'network_firewall_systemd_daemon_reload',
      }
    }

    # Get service list
    if ($dhcp_state) {
      # Include the DHCP client in the services required for automatic network configuration.
      $services = ['dhcpcd', 'lldpd', 'systemd-networkd', 'systemd-resolved', 'networkd-dispatcher']
    } else {
      # Monitor network services without a DHCP client for static configuration.
      $services = ['lldpd', 'systemd-networkd', 'systemd-resolved', 'networkd-dispatcher']
    }

    # Create symlink to network service
    if (defined(Package['dbus'])) {
      file { '/usr/lib/systemd/system/dbus-org.freedesktop.network1.service':
        ensure  => 'link',
        owner   => 'root',
        group   => 'root',
        target  => '/usr/lib/systemd/system/systemd-networkd.service',
        notify  => Exec['network_firewall_systemd_daemon_reload'],
        require => Package['dbus'],
      }
    }
  } else {
    # Keep legacy network services without networkd audit rules when systemd is unavailable.
    $networkd_rules = []
    $services = ['dhcpcd', 'lldpd']
  }

  # Enable lldpd service
  service { 'lldpd':
    ensure  => true,
    enable  => true,
    require => Package['lldpd'],
  }

  # Create lldpd config file
  file { '/etc/lldpd.conf':
    ensure  => file,
    content => template('basic_settings/network/lldpd'),
    owner   => '_lldpd',
    group   => '_lldpd',
    mode    => '0600',
    notify  => Service['lldpd'],
    require => Package['lldpd'],
  }

  # Create service check
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    # Escape the selected service list as one argument for the network check.
    $service_str = join($services, ' ')

    # The monitoring template inserts these lists as shell words without evaluating their contents.
    $service_str_shell = stdlib::shell_escape($service_str)
    $interfaces_str_shell = stdlib::shell_escape($interfaces_str)
    basic_settings::monitoring_custom { 'network':
      content  => template('basic_settings/monitoring/check_network'),
      interval => 600 # 10 minutes
    }
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    # Exclude executables already covered by the root audit rules.
    $suspicious_filter = $suspicious_packages - $suspicious_packages_root
    basic_settings::security_audit { 'network':
      rules                    => $networkd_rules,
      rule_suspicious_packages => $suspicious_filter,
      order                    => 20,
    }

    # Retain login attribution when auditing privileged network tools.
    basic_settings::security_audit { 'network-root':
      rule_suspicious_packages => $suspicious_packages_root,
      rule_options             => ['-F auid!=unset'],
      order                    => 20,
    }
  }
}
