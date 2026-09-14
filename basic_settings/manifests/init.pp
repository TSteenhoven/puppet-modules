# @summary Orchestrates the shared baseline for hardened Debian and Ubuntu servers.
#
# The main `basic_settings` class is the repository foundation. It manages base APT sources, systemd target composition,
# monitoring, security tooling, package hygiene, kernel and network defaults, timezone, locale, login policy, Puppet
# integration, and optional upstream package repositories for local service modules. Many service modules read state
# from this class when it is present, so changes here can affect service ordering, monitoring, package sources, and host
# hardening across the catalog.
#
# @example Build a web host baseline
#   class { 'basic_settings':
#     nginx_enable               => true,
#     mysql_enable               => true,
#     monitoring_package         => 'openitcockpit',
#     monitoring_package_install => true,
#     systemd_ntp_extra_pools    => ['ntp.example.org'],
#   }
#
# @param antivirus_package
#   Optional antivirus integration name used by kernel, network, package, and security components for compatibility
#   exceptions.
#
# @param backports
#   Enables the OS backports repository when the detected platform allows it.
#
# @param cluster_id
#   Prefix for generated systemd target names. The default is `core`.
#
# @param communication_name
#   Optional LLDP communication hostname passed to `basic_settings::network`.
#
# @param description
#   Optional host description reserved for profile data and future templates.
#
# @param dns_dnssec
#   DNSSEC mode passed to systemd-resolved configuration.
#
# @param docker_enable
#   Enables management of the Docker upstream APT repository when supported.
#
# @param docs_enable
#   Enables local documentation packages through `basic_settings::locale`.
#
# @param environment
#   Server environment passed to login policy and network templates, independent of the Puppet code environment;
#   defaults to `production`.
#   See `basic_settings::login` for the environment-dependent shell idle timeout.
#
# @param firewall_package
#   Firewall implementation passed to `basic_settings::network`.
#
# @param firewall_remove
#   Allows the network class to purge competing firewall packages when `true`.
#
# @param getty_enable
#   Controls console getty state through `basic_settings::login`.
#
# @param gitlab_enable
#   Enables management of the GitLab upstream APT repository when supported.
#
# @param guest_agent_enable
#   Enables detected VM guest-agent packages through `basic_settings::kernel`.
#
# @param gui_mode
#   Selects GUI-related package behavior. `none` keeps the host minimal.
#
# @param hosts_enable
#   Enables management of `/etc/hosts` through `basic_settings::network`.
#
# @param hosts_localhost_aliases
#   Additional host aliases appended to the `127.0.0.1 localhost` record.
#
# @param ip_configurator_package
#   Optional network configuration frontend, currently `none` or `netplan.io`.
#
# @param ip_dhcp_enable
#   Enables DHCP client configuration through the network class.
#
# @param ip_ra_enable
#   Enables IPv6 router advertisement handling when DHCP and IP version settings allow it.
#
# @param ip_ra_learn_prefix
#   Controls whether router-advertised prefixes are learned by kernel/network configuration.
#
# @param ip_version
#   Selects IPv4-only (`4`) or dual-stack (`all`) behavior.
#
# @param kernel_connection_max
#   Connection backlog limit passed to kernel templates and consumers.
#
# @param kernel_hugepages
#   Hugepage count passed to the kernel class.
#
# @param kernel_memory_available_profiles
#   Optional MemAvailable threshold profiles passed to `basic_settings::kernel`.
#   `undef` lets the kernel class use its built-in RAM profile list.
#
# @param kernel_mglru_enable
#   Controls Multi-Gen LRU. `true` uses the default, `false` disables it, and an integer sets a custom `min_ttl_ms`.
#
# @param kernel_network_mode
#   Kernel network hardening mode passed to sysctl templates.
#
# @param kernel_ram_disk_package
#   Initramfs implementation selected for the kernel class.
#
# @param kernel_security_lockdown
#   Kernel lockdown setting. `true` maps to `integrity`, `false` maps to `none`, and a string is treated as an explicit
#   lockdown mode.
#
# @param kernel_swap_free_profiles
#   Optional SwapFree threshold profiles passed to `basic_settings::kernel`.
#   `undef` lets the kernel class use its built-in swap profile list.
#
# @param kernel_tcp_congestion_control
#   TCP congestion-control mode passed to `basic_settings::kernel`.
#
# @param kernel_tcp_fastopen
#   TCP Fast Open sysctl value passed to `basic_settings::kernel`.
#
# @param keyboard_enable
#   Optional override for console keyboard management in `basic_settings::assistent`.
#
# @param locale_enable
#   Enables full locale package management through `basic_settings::locale`.
#
# @param lvm_enable
#   Enables LVM package and audit management through `basic_settings::io`.
#
# @param mail_package
#   Mail transport installed for monitoring and systemd failure notifications.
#
# @param mongodb_enable
#   Enables management of the MongoDB upstream APT repository when supported.
#
# @param mongodb_version
#   MongoDB version used when the MongoDB repository is enabled.
#
# @param monitoring_package
#   Monitoring backend to configure. `none` disables generated monitoring integration and `openitcockpit` enables
#   OpenITCOCKPIT custom checks.
#
# @param monitoring_package_install
#   Installs the monitoring agent package when the selected backend supports it.
#
# @param mozilla_enable
#   Enables management of the Mozilla APT repository when supported.
#
# @param mysql_enable
#   Enables management of the MySQL upstream APT repository when supported.
#
# @param mysql_version
#   MySQL version used when the MySQL repository is enabled.
#
# @param network_interfaces
#   Interface patterns passed to network and systemd-networkd helpers.
#
# @param nginx_enable
#   Enables management of the official Nginx APT repository when supported.
#
# @param nodejs_enable
#   Enables management of the NodeSource APT repository when supported.
#
# @param nodejs_version
#   Node.js major version used by the NodeSource repository helper.
#
# @param non_free
#   Optional repository flag reserved for platform source templates.
#
# @param openitcockpit_enable
#   Enables management of the OpenITCOCKPIT APT repository when supported.
#
# @param openitcockpit_license
#   Optional OpenITCOCKPIT repository license token written to root-only APT auth.
#
# @param openitcockpit_nightly
#   Uses the OpenITCOCKPIT nightly repository channel when `true`.
#
# @param openitcockpit_package
#   OpenITCOCKPIT repository family to configure, either `agent` or `server`.
#
# @param openjdk_enable
#   Installs OpenJDK packages independently of Puppet Server requirements when supported.
#
# @param openjdk_version
#   OpenJDK major version to install, or `default` for the OS default JDK.
#
# @param pro_enable
#   Enables Ubuntu Pro client handling through `basic_settings::pro`.
#
# @param pro_monitoring_enable
#   Enables Ubuntu Pro monitoring packages when Pro support is active.
#
# @param proxmox_enable
#   Enables management of the Proxmox APT repository when supported.
#
# @param proxy_http
#   Optional HTTP proxy rendered into APT configuration.
#
# @param proxy_https
#   Optional HTTPS proxy rendered into APT configuration.
#
# @param puppet_repo
#   Optional override for Puppet package layout. `undef` lets the class choose `remote` when Vox Pupuli is enabled and
#   supported, otherwise `distro`.
#
# @param puppetserver_enable
#   Enables Puppet Server/OpenVox Server package and service integration.
#
# @param puppetserver_jvm_memory
#   JVM heap size passed to `basic_settings::puppet`.
#
# @param puppetserver_source
#   Selects Perforce Puppet packages or Vox Pupuli/OpenVox naming.
#
# @param rabbitmq_enable
#   Enables management of RabbitMQ upstream APT repositories when supported.
#
# @param server_fdqn
#   Fully qualified host name passed to monitoring, security, package, and network templates. The default comes from
#   Facter.
#
# @param server_timezone
#   Timezone passed to `basic_settings::timezone`. The default is `UTC`.
#
# @param smtp_server
#   SMTP relay hostname used by modules that render application mail settings.
#
# @param snap_enable
#   Enables snapd in package management. Ubuntu Pro may force this on when Pro is enabled.
#
# @param sudoers_dir_enable
#   Allows `basic_settings::login` to own and purge `/etc/sudoers.d`. Set to `false` on hosts with existing unmanaged
#   sudoers snippets.
#
# @param sury_enable
#   Enables management of the Sury/Ondrej PHP APT repository when supported.
#
# @param systemd_default_target
#   Target suffix selected as the default target in `basic_settings::systemd`.
#
# @param systemd_notify_mail
#   Mail recipient used by generated systemd failure notifications.
#
# @param systemd_ntp_extra_pools
#   Extra NTP pools passed to `basic_settings::timezone`.
#
# @param unattended_upgrades_block_packages
#   Optional replacement list of packages blocked from unattended upgrades.
#
# @param unattended_upgrades_block_packages_extra
#   Additional package patterns appended to the unattended-upgrades block list.
#
# @param unattended_upgrades_reboot
#   Controls whether unattended-upgrades may reboot the host automatically.
#
# @param usb_any_requirements
#   USB monitoring entries where any one matching device satisfies the requirement.
#
# @param usb_expected
#   USB monitoring entries expected to be present.
#
# @param usb_whitelist
#   USB monitoring entries allowed without raising an unauthorized-device alert.
#
# @param voxpupuli_enable
#   Enables management of the Vox Pupuli/OpenVox APT repository when supported.
#
# @param vulnerabilities_package
#   Optional vulnerability scanner integration passed to login policy.
#
# @param vulnerabilities_user
#   User account for the vulnerability scanner integration.
#
# @param wireless_enable
#   Enables wireless package support through `basic_settings::network`.
#
# @api public
class basic_settings (
  Optional[String]                      $antivirus_package                        = undef,
  Boolean                               $backports                                = false,
  String                                $cluster_id                               = 'core',
  Optional[String]                      $communication_name                       = undef,
  Optional[String]                      $description                              = undef,
  Enum['allow-downgrade', 'no']         $dns_dnssec                               = 'allow-downgrade',
  Boolean                               $docker_enable                            = false,
  Boolean                               $docs_enable                              = false,
  String                                $environment                              = 'production',
  String                                $firewall_package                         = 'nftables',
  Boolean                               $firewall_remove                          = true,
  Boolean                               $getty_enable                             = false,
  Boolean                               $gitlab_enable                            = false,
  Boolean                               $guest_agent_enable                       = false,
  Enum['none', 'kiosk', 'adwaita-icon'] $gui_mode                                 = 'none',
  Boolean                               $hosts_enable                             = false,
  Array[String[1]]                      $hosts_localhost_aliases                  = [],
  Enum['none', 'netplan.io']            $ip_configurator_package                  = 'none',
  Boolean                               $ip_dhcp_enable                           = true,
  Boolean                               $ip_ra_enable                             = true,
  Boolean                               $ip_ra_learn_prefix                       = true,
  Enum['all', '4']                      $ip_version                               = 'all',
  Integer                               $kernel_connection_max                    = 4096,
  Integer                               $kernel_hugepages                         = 0,
  Optional[Array[Hash]]                 $kernel_memory_available_profiles         = undef,
  Variant[Boolean, Integer[0]]          $kernel_mglru_enable                      = true,
  String                                $kernel_network_mode                      = 'strict',
  Enum['initramfs', 'dracut']           $kernel_ram_disk_package                  = 'initramfs',
  Variant[Boolean, String]              $kernel_security_lockdown                 = true,
  Optional[Array[Hash]]                 $kernel_swap_free_profiles                = undef,
  String                                $kernel_tcp_congestion_control            = 'brr',
  Integer                               $kernel_tcp_fastopen                      = 3,
  Optional[Boolean]                     $keyboard_enable                          = undef,
  Boolean                               $locale_enable                            = false,
  Boolean                               $lvm_enable                               = false,
  String                                $mail_package                             = 'postfix',
  Boolean                               $mongodb_enable                           = false,
  Float                                 $mongodb_version                          = 8.0,
  Enum['none', 'openitcockpit']         $monitoring_package                       = 'none',
  Boolean                               $monitoring_package_install               = false,
  Boolean                               $mozilla_enable                           = false,
  Boolean                               $mysql_enable                             = false,
  Float                                 $mysql_version                            = 8.0,
  Array                                 $network_interfaces                       = ['eth*', 'ens*', 'wlan*'],
  Boolean                               $nginx_enable                             = false,
  Boolean                               $nodejs_enable                            = false,
  Integer                               $nodejs_version                           = 20,
  Boolean                               $non_free                                 = false,
  Boolean                               $openitcockpit_enable                     = false,
  Optional[String]                      $openitcockpit_license                    = undef,
  Boolean                               $openitcockpit_nightly                    = false,
  Enum['agent', 'server']               $openitcockpit_package                    = 'agent',
  Boolean                               $openjdk_enable                           = false,
  String                                $openjdk_version                          = 'default',
  Boolean                               $pro_enable                               = false,
  Boolean                               $pro_monitoring_enable                    = false,
  Boolean                               $proxmox_enable                           = false,
  Optional[String]                      $proxy_http                               = undef,
  Optional[String]                      $proxy_https                              = undef,
  Optional[Enum['distro', 'remote']]    $puppet_repo                              = undef,
  Boolean                               $puppetserver_enable                      = false,
  Enum['512mb', '1gb', '2gb']           $puppetserver_jvm_memory                  = '2gb',
  Enum['openvox', 'perforce']           $puppetserver_source                      = 'perforce',
  Boolean                               $rabbitmq_enable                          = false,
  String                                $server_fdqn                              = $facts['networking']['fqdn'],
  String                                $server_timezone                          = 'UTC',
  String                                $smtp_server                              = 'localhost',
  Boolean                               $snap_enable                              = false,
  Boolean                               $sudoers_dir_enable                       = true,
  Boolean                               $sury_enable                              = false,
  String                                $systemd_default_target                   = 'helpers',
  String                                $systemd_notify_mail                      = 'root',
  Array                                 $systemd_ntp_extra_pools                  = [],
  Optional[Array]                       $unattended_upgrades_block_packages       = undef,
  Array                                 $unattended_upgrades_block_packages_extra = [],
  Boolean                               $unattended_upgrades_reboot               = false,
  Array                                 $usb_any_requirements                     = [],
  Array                                 $usb_expected                             = [],
  Array                                 $usb_whitelist                            = [],
  Boolean                               $voxpupuli_enable                         = false,
  Optional[String]                      $vulnerabilities_package                  = undef,
  Optional[String]                      $vulnerabilities_user                     = undef,
  Boolean                               $wireless_enable                          = false,
) {
  # Get puppet prefix
  case $puppetserver_source {
    'perforce': {
      # Use the Puppet package family and its server package name.
      $puppetserver_prefix = 'puppet'
      $puppetserver_master = 'puppet-master'
    }
    'openvox': {
      # Use the OpenVox package family and its server package name.
      $puppetserver_prefix = 'openvox-'
      $puppetserver_master = 'openvox-server'
    }
    default: {
      # The public enum restricts this selector to the supported package families.
    }
  }

  # Get OS name
  case $facts['os']['name'] {
    'Ubuntu': {
      # Set some variables
      $os_parent = 'ubuntu'
      $os_repo = 'main universe restricted'

      # Select the Ubuntu archive that publishes packages for this architecture.
      if ($facts['os']['architecture'] == 'amd64') {
        # Use the main Ubuntu mirrors for amd64 packages.
        $os_url = 'http://archive.ubuntu.com/ubuntu/'
        $os_url_security = 'http://security.ubuntu.com/ubuntu'
      } else {
        # Use the Ubuntu ports mirrors for other architectures.
        $os_url = 'http://ports.ubuntu.com/ubuntu-ports/'
        $os_url_security = 'http://ports.ubuntu.com/ubuntu-ports/'
      }

      # Do thing based on version
      if ($facts['os']['release']['major'] == '26.04') { # LTS
        # Select the repository formats and package capabilities for Ubuntu 26.04.
        $backports_allow = false
        $deb_version = '822'
        $docker_allow = true
        $gcc_version = 16
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Restrict these third-party database repositories to their supported architecture.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL and RabbitMQ repository paths selected for amd64.
          $mysql_allow = true
          $rabbitmq_allow = true
        } else {
          # Disable the MySQL and RabbitMQ repository paths on other architectures.
          $mysql_allow = false
          $rabbitmq_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'resolute'
        $ram_disk_package = 'initramfs'
        $proxmox_allow = false
        $puppetserver_dirname = 'puppetserver'
        $puppetserver_jdk = true
        $puppetserver_package = "${puppetserver_prefix}server"
        $sury_allow = true
        $voxpupuli_allow = true
      } elsif ($facts['os']['release']['major'] == '24.04') { # LTS
        # Select the repository formats and package capabilities for Ubuntu 24.04.
        $backports_allow = false
        $deb_version = '822'
        $docker_allow = true
        $gcc_version = 14
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Restrict these third-party database repositories to their supported architecture.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL and RabbitMQ repository paths selected for amd64.
          $mysql_allow = true
          $rabbitmq_allow = true
        } else {
          # Disable the MySQL and RabbitMQ repository paths on other architectures.
          $mysql_allow = false
          $rabbitmq_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'noble'
        $ram_disk_package = 'initramfs'
        $proxmox_allow = false
        $puppetserver_dirname = 'puppetserver'
        $puppetserver_jdk = true
        $puppetserver_package = "${puppetserver_prefix}server"
        $sury_allow = true
        $voxpupuli_allow = true
      } elsif ($facts['os']['release']['major'] == '23.04') { # Stable
        # Select the repository formats and package capabilities for Ubuntu 23.04.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = true
        $gcc_version = 12
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Limit MySQL to amd64 while retaining RabbitMQ availability on the other architecture path.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL and RabbitMQ repository paths selected for amd64.
          $mysql_allow = true
          $rabbitmq_allow = true
        } else {
          # Keep RabbitMQ available while disabling the MySQL repository on other architectures.
          $mysql_allow = false
          $rabbitmq_allow = true
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'lunar'
        $ram_disk_package = 'initramfs'
        $proxmox_allow = false
        $puppetserver_dirname = 'puppetserver'
        $puppetserver_jdk = true
        $puppetserver_package = "${puppetserver_prefix}server"
        $sury_allow = false
        $voxpupuli_allow = true
      } elsif ($facts['os']['release']['major'] == '22.04') { # LTS
        # Select the repository formats and package capabilities for Ubuntu 22.04.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = true
        $gcc_version = 12
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Restrict these third-party database repositories to their supported architecture.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL and RabbitMQ repository paths selected for amd64.
          $mysql_allow = true
          $rabbitmq_allow = true
        } else {
          # Disable the MySQL and RabbitMQ repository paths on other architectures.
          $mysql_allow = false
          $rabbitmq_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'jammy'
        $ram_disk_package = 'initramfs'
        $proxmox_allow = false
        $puppetserver_dirname = 'puppet'
        $puppetserver_jdk = false
        $puppetserver_package = $puppetserver_master
        $sury_allow = true
        $voxpupuli_allow = true
      } else {
        # Disable optional repositories and integrations when no platform mapping is available.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = false
        $gcc_version = undef
        $gitlab_allow = false
        $mongodb_allow = false
        $mozilla_allow = false
        $mysql_allow = false
        $nginx_allow = false
        $nodejs_allow = false
        $openitcockpit_allow = false
        $openjdk_allow = false
        $os_name = 'unknown'
        $ram_disk_package = 'initramfs'
        $rabbitmq_allow = false
        $proxmox_allow = false
        $puppetserver_dirname = 'puppet'
        $puppetserver_jdk = false
        $puppetserver_package = $puppetserver_master
        $sury_allow = false
        $voxpupuli_allow = false
      }
    }
    'Debian': {
      # Set some variables
      $os_parent = 'debian'
      $os_repo = 'main contrib non-free-firmware'
      $os_url = 'http://deb.debian.org/debian/'
      $os_url_security = 'http://deb.debian.org/debian-security/'

      # Do thing based on version
      if ($facts['os']['release']['major'] == '13') {
        # Select the repository formats and package capabilities for Debian 13.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = true
        $gcc_version = undef
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Enable the upstream MySQL repository only for amd64.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL repository path selected for amd64.
          $mysql_allow = true
        } else {
          # Disable the MySQL repository path on other architectures.
          $mysql_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'trixie'
        $ram_disk_package = 'initramfs'
        $rabbitmq_allow = true
        $proxmox_allow = false
        $puppetserver_dirname = 'puppetserver'
        $puppetserver_jdk = true
        $puppetserver_package = "${puppetserver_prefix}server"
        $sury_allow = true
        $voxpupuli_allow = true
      } elsif ($facts['os']['release']['major'] == '12') {
        # Select the repository formats and package capabilities for Debian 12.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = true
        $gcc_version = undef
        $gitlab_allow = true
        $mongodb_allow = true
        $mozilla_allow = true

        # Enable the upstream MySQL repository only for amd64.
        if ($facts['os']['architecture'] == 'amd64') {
          # Enable the MySQL repository path selected for amd64.
          $mysql_allow = true
        } else {
          # Disable the MySQL repository path on other architectures.
          $mysql_allow = false
        }
        $nginx_allow = true
        $nodejs_allow = true
        $openitcockpit_allow = true
        $openjdk_allow = true
        $os_name = 'bookworm'
        $ram_disk_package = 'initramfs'
        $rabbitmq_allow = true
        $proxmox_allow = false
        $puppetserver_dirname = 'puppetserver'
        $puppetserver_jdk = true
        $puppetserver_package = "${puppetserver_prefix}server"
        $sury_allow = true
        $voxpupuli_allow = true
      } else {
        # Disable optional repositories and integrations when no platform mapping is available.
        $backports_allow = false
        $deb_version = 'list'
        $docker_allow = false
        $gcc_version = undef
        $gitlab_allow = false
        $mongodb_allow = false
        $mozilla_allow = false
        $mysql_allow = false
        $nginx_allow = false
        $nodejs_allow = false
        $openitcockpit_allow = false
        $openjdk_allow = false
        $os_name = 'unknown'
        $ram_disk_package = 'initramfs'
        $rabbitmq_allow = false
        $proxmox_allow = false
        $puppetserver_dirname = 'puppet'
        $puppetserver_jdk = false
        $puppetserver_package = $puppetserver_master
        $sury_allow = false
        $voxpupuli_allow = false
      }
    }
    default: {
      # Disable optional repositories and integrations when no platform mapping is available.
      $backports_allow = false
      $deb_version = 'list'
      $docker_allow = false
      $gcc_version = undef
      $gitlab_allow = false
      $mongodb_allow = false
      $mozilla_allow = false
      $mysql_allow = false
      $nginx_allow = false
      $nodejs_allow = false
      $openitcockpit_allow = false
      $openjdk_allow = false
      $os_name = 'unknown'
      $ram_disk_package = 'initramfs'
      $rabbitmq_allow = false
      $proxmox_allow = false
      $puppetserver_dirname = 'puppet'
      $puppetserver_jdk = false
      $puppetserver_package = $puppetserver_master
      $sury_allow = false
    }
  }

  # Get ramdisk package
  if ($kernel_ram_disk_package == undef) {
    # Use the platform's default initramfs implementation.
    $kernel_ram_disk_package_correct = $ram_disk_package
  } else {
    # Preserve the requested initramfs implementation.
    $kernel_ram_disk_package_correct = $kernel_ram_disk_package
  }

  # Get snap state
  if ($pro_enable and !$snap_enable) {
    # Keep Snap available for the enabled Ubuntu Pro integration.
    $snap_correct = true
  } else {
    # Honor the caller's Snap setting when Pro does not require it.
    $snap_correct = $snap_enable
  }

  # Get IP RA state
  if ($ip_dhcp_enable and $ip_ra_enable) {
    case $ip_version {
      '4': {
        # Disable IPv6 router advertisements on an IPv4-only host.
        $ip_ra_enable_correct = false
      }
      default: {
        # Preserve the requested router-advertisement setting when IPv6 is available.
        $ip_ra_enable_correct = $ip_ra_enable
      }
    }
  } else {
    # Disable router advertisements when DHCP or router-advertisement handling is turned off.
    $ip_ra_enable_correct = false
  }

  # Get audio state
  case $gui_mode {
    'kiosk': {
      # Enable audio support for the selected kiosk configuration.
      $audio_enable = true
    }
    default: {
      # Leave audio support disabled outside the kiosk configuration.
      $audio_enable = false
    }
  }

  # Basic system packages; This packages needed to be installed first
  package { ['apt', 'apt-transport-https', 'bc', 'coreutils', 'curl', 'dpkg', 'findutils', 'grep', 'gnupg', 'jq', 'lsb-release', 'kmod', 'sed', 'util-linux']: # lint:ignore:140chars
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Basic system packages
  package { 'sysstat':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Reload source list
  exec { 'basic_settings_source_reload':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
  }

  # Use the source-list format selected for this platform.
  if ($deb_version != '822') {
    # Check if we need backports
    $backports_file = "/etc/apt/sources.list.d/${os_name}-backports.list"

    # Escape the backports path before using it in exec commands and guards.
    $backports_file_shell = stdlib::shell_escape($backports_file)

    # Manage the backports source according to both the request and platform availability.
    if ($backports and $backports_allow) {
      # Prepare the backports package options and repository content together.
      $backports_install_options = ['-t', "${os_name}-backports"]

      # Escape generated backports source content before the shell writes it.
      $backports_source_shell = stdlib::shell_escape("deb ${os_url} ${os_name}-backports ${os_repo}\n")
      exec { 'basic_settings_source_backports':
        command => "/usr/bin/printf %s ${backports_source_shell} > ${backports_file_shell}",
        unless  => "/usr/bin/test -e ${backports_file_shell}",
        notify  => Exec['basic_settings_source_reload'],
        require => Package['apt', 'coreutils'],
      }
    } else {
      # Use normal package selection when backports are not enabled.
      $backports_install_options = []
      exec { 'basic_settings_source_backports':
        command => "/usr/bin/rm ${backports_file_shell}",
        onlyif  => "/usr/bin/test -e ${backports_file_shell}",
        notify  => Exec['basic_settings_source_reload'],
        require => Package['apt', 'coreutils'],
      }
    }

    # Based on OS parent use correct source list
    file { 'basic_settings_source':
      ensure  => file,
      path    => '/etc/apt/sources.list',
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => template("basic_settings/source/${os_parent}.list"),
      notify  => Exec['basic_settings_source_reload'],
      require => Exec['basic_settings_source_backports'],
    }
  } else {
    # Based on OS parent use correct source list
    file { '/etc/apt/sources.list':
      ensure  => file,
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => "# Managed by puppet\n# ${facts['os']['name']} sourcess have to moved to /etc/apt/sources.list.d/${os_parent}.sources\n",
      notify  => Exec['basic_settings_source_reload'],
      require => Package['apt'],
    }

    # Based on OS parent use correct source list
    file { 'basic_settings_source':
      ensure  => file,
      path    => "/etc/apt/sources.list.d/${os_parent}.sources",
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => template("basic_settings/source/${os_parent}.sources"),
      notify  => Exec['basic_settings_source_reload'],
      require => [Package['apt'], File['/etc/apt/sources.list']],
    }

    # Check if we need backports
    if ($backports and $backports_allow) {
      # Select packages from the distribution's backports suite.
      $backports_install_options = ['-t', "${os_name}-backports"]
    } else {
      # Use normal package selection when backports are not enabled.
      $backports_install_options = []
    }
  }

  # Set systemd
  class { 'basic_settings::systemd':
    cluster_id      => $cluster_id,
    default_target  => $systemd_default_target,
    install_options => $backports_install_options,
    require         => File['basic_settings_source']
  }

  # Special case when monitoring_package is not none
  if ($monitoring_package != 'none') {
    # Check if variable openitcockpit is true; if true, install new source list and key
    if ($openitcockpit_enable and $openitcockpit_allow) {
      class { 'basic_settings::package_openitcockpit':
        deb_version => $deb_version,
        enable      => true,
        license     => $openitcockpit_license,
        nightly     => $openitcockpit_nightly,
        package     => $openitcockpit_package,
        os_parent   => $os_parent,
        os_name     => $os_name,
      }
    } else {
      class { 'basic_settings::package_openitcockpit':
        deb_version => $deb_version,
        enable      => false,
        license     => $openitcockpit_license,
        nightly     => $openitcockpit_nightly,
        package     => $openitcockpit_package,
        os_parent   => $os_parent,
        os_name     => $os_name,
      }
    }
    $monitoring_requirements = Class['basic_settings::package_openitcockpit', 'basic_settings::systemd']
  } else {
    # Retain systemd ordering without requiring an OpenITCockpit repository.
    $monitoring_requirements = Class['basic_settings::systemd']
  }

  # Setup message
  class { 'basic_settings::monitoring':
    mail_to            => $systemd_notify_mail,
    mail_package       => $mail_package,
    package            => $monitoring_package,
    package_install    => $monitoring_package_install,
    server_fdqn        => $server_fdqn,
    sudoers_dir_enable => $sudoers_dir_enable,
    require            => $monitoring_requirements,
  }

  # Setup security
  class { 'basic_settings::security':
    antivirus_package => $antivirus_package,
    mail_to           => $systemd_notify_mail,
    server_fdqn       => $server_fdqn,
    require           => Class['basic_settings::monitoring'],
  }

  # Set IO
  class { 'basic_settings::io':
    lvm_enable => $lvm_enable,
    require    => Class['basic_settings::monitoring'],
  }

  # Setup APT
  class { 'basic_settings::packages':
    antivirus_package                        => $antivirus_package,
    ip_version                               => $ip_version,
    mail_to                                  => $systemd_notify_mail,
    server_fdqn                              => $server_fdqn,
    snap_enable                              => $snap_correct,
    proxy_http                               => $proxy_http,
    proxy_https                              => $proxy_https,
    unattended_upgrades_block_packages       => $unattended_upgrades_block_packages,
    unattended_upgrades_block_packages_extra => $unattended_upgrades_block_packages_extra,
    unattended_upgrades_reboot               => $unattended_upgrades_reboot,
    require                                  => [
      File['/etc/apt/sources.list'],
      Class['basic_settings::monitoring'],
    ],
  }

  # Set Pro
  class { 'basic_settings::pro':
    enable            => $pro_enable,
    monitoring_enable => $pro_monitoring_enable,
    require           => Class['basic_settings::monitoring']
  }

  # Set timezone
  class { 'basic_settings::timezone':
    timezone        => $server_timezone,
    ntp_extra_pools => $systemd_ntp_extra_pools,
    install_options => $backports_install_options,
    require         => [File['basic_settings_source'], Class['basic_settings::monitoring']],
  }

  # Setup kernel
  class { 'basic_settings::kernel':
    antivirus_package         => $antivirus_package,
    connection_max            => $kernel_connection_max,
    guest_agent_enable        => $guest_agent_enable,
    hugepages                 => $kernel_hugepages,
    install_options           => $backports_install_options,
    ip_version                => $ip_version,
    ip_ra_enable              => $ip_ra_enable_correct,
    ip_ra_learn_prefix        => $ip_ra_learn_prefix,
    memory_available_profiles => $kernel_memory_available_profiles,
    mglru_enable              => $kernel_mglru_enable,
    network_mode              => $kernel_network_mode,
    ram_disk_package          => $kernel_ram_disk_package_correct,
    security_lockdown         => $kernel_security_lockdown,
    swap_free_profiles        => $kernel_swap_free_profiles,
    tcp_congestion_control    => $kernel_tcp_congestion_control,
    tcp_fastopen              => $kernel_tcp_fastopen,
    usb_whitelist             => $usb_whitelist,
    usb_expected              => $usb_expected,
    usb_any_requirements      => $usb_any_requirements
  }

  # Set network
  class { 'basic_settings::network':
    antivirus_package       => $antivirus_package,
    communication_name      => $communication_name,
    configurator_package    => $ip_configurator_package,
    dhcp_enable             => $ip_dhcp_enable,
    dns_dnssec              => $dns_dnssec,
    environment             => $environment,
    firewall_package        => $firewall_package,
    firewall_remove         => $firewall_remove,
    hosts_enable            => $hosts_enable,
    hosts_localhost_aliases => $hosts_localhost_aliases,
    install_options         => $backports_install_options,
    interfaces              => $network_interfaces,
    server_fdqn             => $server_fdqn,
    wireless_enable         => $wireless_enable,
    require                 => [File['basic_settings_source'], Class['basic_settings::monitoring']],
  }

  # Set timezone
  class { 'basic_settings::locale':
    enable              => $locale_enable,
    docs_enable         => $docs_enable
  }

  # Set assistent
  class { 'basic_settings::assistent':
    audio_enable    => $audio_enable,
    keyboard_enable => $keyboard_enable,
  }

  # Check if variable docket is true; if true, install new source list and key
  if ($docker_enable and $docker_allow) {
    class { 'basic_settings::package_docker':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_docker':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable gitlab is true; if true, install new source list and key
  if ($gitlab_enable and $gitlab_allow) {
    class { 'basic_settings::package_gitlab':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_gitlab':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Special case when monitoring_package is none
  if ($monitoring_package == 'none') {
    # Check if variable openitcockpit is true; if true, install new source list and key
    if ($openitcockpit_enable and $openitcockpit_allow) {
      class { 'basic_settings::package_openitcockpit':
        deb_version => $deb_version,
        enable      => true,
        license     => $openitcockpit_license,
        nightly     => $openitcockpit_nightly,
        package     => $openitcockpit_package,
        os_parent   => $os_parent,
        os_name     => $os_name,
      }
    } else {
      class { 'basic_settings::package_openitcockpit':
        deb_version => $deb_version,
        enable      => false,
        license     => $openitcockpit_license,
        nightly     => $openitcockpit_nightly,
        package     => $openitcockpit_package,
        os_parent   => $os_parent,
        os_name     => $os_name,
      }
    }
  }

  # Check if variable mysql is true; if true, install new source list and key
  if ($mongodb_enable and $mongodb_allow) {
    class { 'basic_settings::package_mongodb':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
      version     => $mongodb_version,
    }
  } else {
    class { 'basic_settings::package_mongodb':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable mozilla is true; if true, install new source list and key
  if ($mozilla_enable and $mozilla_allow) {
    class { 'basic_settings::package_mozilla':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_mozilla':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable mysql is true; if true, install new source list and key
  if ($mysql_enable and $mysql_allow) {
    class { 'basic_settings::package_mysql':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
      version     => $mysql_version,
    }
  } else {
    class { 'basic_settings::package_mysql':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable nginx is true; if true, install new source list and key
  if ($nginx_enable and $nginx_allow) {
    class { 'basic_settings::package_nginx':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_nginx':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable nodejs is true; if true, install new source list and key
  if ($nodejs_enable and $nodejs_allow) {
    class { 'basic_settings::package_node':
      deb_version => $deb_version,
      enable      => true,
      version     => $nodejs_version,
    }
  } else {
    class { 'basic_settings::package_node':
      deb_version => $deb_version,
      enable      => false,
    }
  }

  # Check if variable proxmox is true; if true, install new source list and key
  if ($proxmox_enable and $proxmox_allow) {
    class { 'basic_settings::package_proxmox':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_proxmox':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable rabbitmq is true; if true, install new source list and key
  if ($rabbitmq_enable and $rabbitmq_allow) {
    class { 'basic_settings::package_rabbitmq':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_rabbitmq':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable rabbitmq is true; if true, install new source list and key
  if ($sury_enable and $sury_allow) {
    class { 'basic_settings::package_sury':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  } else {
    class { 'basic_settings::package_sury':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_name     => $os_name,
    }
  }

  # Check if variable sury is true; if true, install new source list and key
  if ($voxpupuli_enable and $voxpupuli_allow) {
    class { 'basic_settings::package_voxpupuli':
      deb_version => $deb_version,
      enable      => true,
      os_parent   => $os_parent,
      os_version  => $facts['os']['release']['major'],
    }
  } else {
    class { 'basic_settings::package_voxpupuli':
      deb_version => $deb_version,
      enable      => false,
      os_parent   => $os_parent,
      os_version  => $facts['os']['release']['major'],
    }
  }

  # Try to get puppet repo
  if ($puppet_repo == undef) {
    # Select the remote OpenVox repository only when it is enabled and supported.
    if ($voxpupuli_enable and $voxpupuli_allow) {
      # Select the enabled external OpenVox repository.
      $puppet_repo_correct = 'remote'
    } else {
      # Fall back to packages provided by the distribution.
      $puppet_repo_correct = 'distro'
    }
  } else {
    # Fall back to packages provided by the distribution.
    $puppet_repo_correct = 'distro'
  }

  # Remove Java when no enabled feature needs it, retaining GUI dependencies according to the selected mode.
  if (!(($puppetserver_enable and $puppetserver_jdk) or ($openjdk_enable and $openjdk_allow))) {
    # Remove openjdk package
    package { 'openjdk':
      ensure => purged,
      name   => 'openjdk*',
    }

    # Setup GUI mode
    case $gui_mode {
      'kiosk': {
        # Enable the icon theme and configuration service needed by the kiosk desktop.
        $adwaita_icon_theme_enable = true
        $dconf_service_enable = true
      }
      'adwaita-icon': {
        # Keep the icon theme without enabling the desktop configuration service.
        $adwaita_icon_theme_enable = true
        $dconf_service_enable = false
      }
      default: {
        # Omit desktop dependencies when no selected component needs them.
        $adwaita_icon_theme_enable = false
        $dconf_service_enable = false
      }
    }

    # Retain icon themes required by the selected GUI mode when Java is removed.
    if ($adwaita_icon_theme_enable) {
      # Install adwaita icon package
      package { 'adwaita-icon-theme':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['openjdk'],
      }
    } else {
      # Remove adwaita icon package
      package { 'adwaita-icon-theme':
        ensure  => purged,
        require => Package['openjdk'],
      }
    }

    # Retain dconf only when the selected GUI mode still needs it.
    if ($dconf_service_enable) {
      # Install dconf service package
      package { 'dconf-service':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['openjdk'],
      }
    } else {
      # Remove dconf service package
      package { 'dconf-service':
        ensure  => purged,
        require => Package['openjdk'],
      }
    }

    # Remove java extensions
    package { ['ca-certificates-java']:
      ensure  => purged,
      require => Package['openjdk'],
    }
  } else {
    # Get package name
    if ($puppetserver_enable or $openjdk_version == 'default') {
      # Let the distribution choose its default JDK package.
      $openjdk_package = 'default-jdk'
    } else {
      # Select the explicitly requested JDK version.
      $openjdk_package = "openjdk-${openjdk_version}-jdk"
    }

    # Install openjdk package
    package { 'openjdk':
      ensure          => installed,
      name            => $openjdk_package,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Install java extensions
    package { ['adwaita-icon-theme', 'ca-certificates-java', 'dconf-service']:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['openjdk'],
    }
  }

  # Setup development
  class { 'basic_settings::development':
    gcc_version     => $gcc_version,
    install_options => $backports_install_options,
    require         => File['basic_settings_source']
  }

  # Setup Puppet
  class { 'basic_settings::puppet':
    jvm_memory      => $puppetserver_jvm_memory,
    repo            => $puppet_repo_correct,
    server_dirname  => $puppetserver_dirname,
    server_enable   => $puppetserver_enable,
    server_package  => $puppetserver_package,
  }

  # Setup login
  class { 'basic_settings::login':
    environment             => $environment,
    getty_enable            => $getty_enable,
    gui_mode                => $gui_mode,
    mail_to                 => $systemd_notify_mail,
    server_fdqn             => $server_fdqn,
    sudoers_dir_enable      => $sudoers_dir_enable,
    vulnerabilities_package => $vulnerabilities_package,
    vulnerabilities_user    => $vulnerabilities_user,
  }
}
