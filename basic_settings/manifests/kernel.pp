# @summary Applies kernel, boot, sysctl, CPU, USB, and hardware hardening settings.
#
# This class manages kernel-related packages and configuration for Debian and Ubuntu servers. It owns sysctl files,
# bootloader configuration, optional hugepage setup, kernel lockdown, MGLRU, TCP tuning, selected hardware tools,
# guest-agent packages, USB monitoring input, and audit rules for kernel-sensitive commands. Several settings directly
# affect boot behavior and should be changed only after validating the target hardware and virtualization platform.
#
# @example Use the default hardened kernel profile
#   include basic_settings::kernel
#
# @example Enable hugepages and use an explicit lockdown mode
#   class { 'basic_settings::kernel':
#     hugepages         => 1024,
#     security_lockdown => 'integrity',
#   }
#
# @param antivirus_package
#   Optional antivirus integration name. Some values loosen lockdown behavior where the antivirus package needs kernel
#   access.
#
# @param bootloader
#   Bootloader family to manage. The default is `grub`; unsupported values skip bootloader-specific management.
#
# @param connection_max
#   Connection backlog value used by sysctl templates and by consumers that inherit kernel connection limits. The
#   default is 4096.
#
# @param cpu_governor
#   CPU governor policy used for physical hosts. The default is `performance`.
#
# @param guest_agent_enable
#   Installs the detected VM guest agent when `true`; purges it when `false`.
#
# @param hardware_passthrough
#   Overrides whether firmware and hardware-passthrough tooling is managed.
#   `undef` enables it on physical hosts and disables it on virtual machines.
#
# @param hugepages
#   Number of hugepages to configure. Values greater than zero create the `hugetlb` group and related systemd/sysctl
#   handling.
#
# @param install_options
#   Additional APT options; an empty array adds no caller options. Mandatory no-recommends and no-suggests flags are
#   appended without deduplication so they remain effective.
#
# @param ip_ra_enable
#   Controls IPv6 router advertisement handling in generated sysctl and network defaults.
#
# @param ip_ra_learn_prefix
#   Controls whether router-advertised prefixes are learned when RA support is active.
#
# @param ip_regdom
#   Wireless regulatory domain used by kernel templates. The default is `NL`.
#
# @param ip_version
#   Selects IPv4-only (`4`) or dual-stack (`all`) behavior for kernel and network templates.
#
# @param memory_available_profiles
#   Optional MemAvailable threshold profiles for memory-pressure monitoring.
#   `undef` resolves to the built-in RAM profile list. Each profile hash accepts `max_ram`, `warning`, and `critical`;
#   the final profile uses `max_ram => undef` as the open-ended fallback. The generated check validates profile syntax,
#   size values, and threshold ordering at runtime.
#
# @param mglru_enable
#   Controls Multi-Gen LRU. `true` uses the default `min_ttl_ms` of 1000, `false` disables MGLRU, and an integer sets a
#   custom `min_ttl_ms`.
#
# @param network_mode
#   Kernel network hardening mode consumed by the sysctl templates.
#
# @param ram_disk_package
#   Selects the initramfs implementation to install and retain. Valid values are `initramfs` and `dracut`.
#
# @param security_lockdown
#   Controls kernel lockdown. `true` resolves to `integrity`, `false` resolves to `none`, and a string is written as the
#   explicit requested mode. Secure Boot enforces at least `integrity`.
#
# @param swap_free_profiles
#   Optional SwapFree threshold profiles for memory-pressure monitoring. `undef` resolves to the built-in swap profile
#   list. Each profile hash accepts `max_swap`, `warning`, and `critical`; the final profile uses `max_swap => undef` as
#   the open-ended fallback. The generated check validates profile syntax, size values, and threshold ordering at
#   runtime.
#
# @param tcp_congestion_control
#   TCP congestion-control mode. The `bbr` value writes the BBR sysctl snippet when kernel support is present; other
#   values remove that snippet.
#
# @param tcp_fastopen
#   TCP Fast Open sysctl value used by kernel templates and consumers. The default is 3.
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
# @api public
class basic_settings::kernel (
  Optional[String]             $antivirus_package         = undef,
  String                       $bootloader                = 'grub',
  Integer                      $connection_max            = 4096,
  String                       $cpu_governor              = 'performance',
  Boolean                      $guest_agent_enable        = false,
  Optional[Boolean]            $hardware_passthrough      = undef,
  Integer                      $hugepages                 = 0,
  Array                        $install_options           = [],
  Boolean                      $ip_ra_enable              = true,
  Boolean                      $ip_ra_learn_prefix        = true,
  String                       $ip_regdom                 = 'NL',
  Enum['all', '4']             $ip_version                = 'all',
  Optional[Array[Hash]]        $memory_available_profiles = undef,
  Variant[Boolean, Integer[0]] $mglru_enable              = true,
  String                       $network_mode              = 'strict',
  Enum['initramfs', 'dracut']  $ram_disk_package          = 'initramfs',
  Variant[Boolean, String]     $security_lockdown         = true,
  Optional[Array[Hash]]        $swap_free_profiles        = undef,
  String                       $tcp_congestion_control    = 'brr',
  Integer                      $tcp_fastopen              = 3,
  Array                        $usb_any_requirements      = [],
  Array                        $usb_expected              = [],
  Array                        $usb_whitelist             = [],
) {
  # Set variables
  $os_name = $facts['os']['name'];
  $os_version = $facts['os']['release']['major']
  $kernel_type = $facts['kernelrelease'] ? {
    /-raspi$/   => 'raspi',
    /-generic$/ => 'generic',
    default     => 'other',
  }
  $systemd_enable = defined(Package['systemd'])

  # Serialize configured USB filters as literal shell words before rendering the monitoring assignments.
  $usb_whitelist_shell = stdlib::shell_escape(join($usb_whitelist, ' '))
  $usb_expected_shell = stdlib::shell_escape(join($usb_expected, ' '))
  $usb_any_requirements_shell = stdlib::shell_escape(join($usb_any_requirements, ' '))

  # Resolve the built-in MemAvailable profile list only when no caller overrides it.
  $memory_available_profiles_correct = $memory_available_profiles ? {
    undef   => [
      { 'max_ram' => '4GB', 'warning' => '768MB', 'critical' => '384MB' },
      { 'max_ram' => '8GB', 'warning' => '1024MB', 'critical' => '512MB' },
      { 'max_ram' => '16GB', 'warning' => '1536MB', 'critical' => '768MB' },
      { 'max_ram' => '32GB', 'warning' => '2048MB', 'critical' => '1024MB' },
      { 'max_ram' => '64GB', 'warning' => '3072MB', 'critical' => '1536MB' },
      { 'max_ram' => undef, 'warning' => '4096MB', 'critical' => '2048MB' },
    ],
    default => $memory_available_profiles,
  }

  # Serialize profile hashes into a compact shell list; the monitoring check validates sizes and ordering at runtime.
  $memory_available_profile_specs = $memory_available_profiles_correct.map |$profile| {
    # Represent omitted memory-profile limits as empty fields for the check configuration.
    $memory_profile_max = $profile['max_ram'] ? {
      undef   => '',
      default => $profile['max_ram'],
    }
    $memory_profile_warning = $profile['warning'] ? {
      undef   => '',
      default => $profile['warning'],
    }
    $memory_profile_critical = $profile['critical'] ? {
      undef   => '',
      default => $profile['critical'],
    }

    "${memory_profile_max}|${memory_profile_warning}|${memory_profile_critical}"
  }
  $memory_available_profiles_spec = join($memory_available_profile_specs, ',')
  $memory_available_profiles_spec_shell = stdlib::shell_escape($memory_available_profiles_spec)

  # Resolve the built-in SwapFree profile list only when no caller overrides it.
  $swap_free_profiles_correct = $swap_free_profiles ? {
    undef   => [
      { 'max_swap' => '1GB', 'warning' => '128MB', 'critical' => '32MB' },
      { 'max_swap' => '2GB', 'warning' => '256MB', 'critical' => '64MB' },
      { 'max_swap' => '4GB', 'warning' => '512MB', 'critical' => '128MB' },
      { 'max_swap' => undef, 'warning' => '1024MB', 'critical' => '256MB' },
    ],
    default => $swap_free_profiles,
  }

  # Serialize swap profile hashes into a compact shell list; the monitoring check validates sizes and ordering at runtime.
  $swap_free_profile_specs = $swap_free_profiles_correct.map |$profile| {
    # Represent omitted swap-profile limits as empty fields for the check configuration.
    $swap_profile_max = $profile['max_swap'] ? {
      undef   => '',
      default => $profile['max_swap'],
    }
    $swap_profile_warning = $profile['warning'] ? {
      undef   => '',
      default => $profile['warning'],
    }
    $swap_profile_critical = $profile['critical'] ? {
      undef   => '',
      default => $profile['critical'],
    }

    "${swap_profile_max}|${swap_profile_warning}|${swap_profile_critical}"
  }
  $swap_free_profiles_spec = join($swap_free_profile_specs, ',')
  $swap_free_profiles_spec_shell = stdlib::shell_escape($swap_free_profiles_spec)

  # Resolve MGLRU to the default min_ttl_ms, a custom min_ttl_ms, or disabled.
  $mglru_min_ttl_ms_correct = $mglru_enable ? {
    true    => 1000,
    false   => 0,
    default => $mglru_enable,
  }
  $mglru_active = $mglru_enable ? {
    false   => false,
    default => true,
  }

  # Resolve kernel lockdown to the default, an explicit value, or none for opt-out.
  $security_lockdown_default = 'integrity'
  $security_lockdown_requested = $security_lockdown ? {
    true    => $security_lockdown_default,
    false   => 'none',
    default => $security_lockdown,
  }

  # Set monitoring variables
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  if ($monitoring_enable) {
    # Route unit failures through the configured monitoring notification service.
    $unit_failure = {
      'OnFailure' => 'notify-failed@%i.service',
    }
  } else {
    # Leave unit failure hooks empty when monitoring is unavailable.
    $unit_failure = {}
  }

  # Try to get some settings
  if ($facts['is_virtual']) {
    case $facts['virtual'] {
      'vmware': {
        # Select the guest integration package for VMware.
        $guest_agent_package = 'open-vm-tools'
      }
      default: {
        # Select the guest integration package for QEMU-compatible virtualization.
        $guest_agent_package = 'qemu-guest-agent'
      }
    }

    # Check if we need extra tools for hardware passthrough
    if ($hardware_passthrough == undef) {
      # Keep hardware passthrough disabled by default in a virtual machine.
      $hardware_passthrough_correct = false
    } else {
      # Preserve the explicit hardware-passthrough setting for this guest.
      $hardware_passthrough_correct = $hardware_passthrough
    }
  } else {
    # Allow direct hardware access on physical hosts without a guest-agent package.
    $hardware_passthrough_correct = true
    $guest_agent_package = undef
  }

  # When efi, the minimal lockdown state is integrity
  if (!$facts['secure_boot_enabled']) {
    # Override some settings when we have antivirus or we are virtual machine
    case $antivirus_package {
      'eset': {
        # Relax kernel lockdown for the selected ESET integration.
        $security_lockdown_correct = 'none'
      }
      default: {
        # Relax lockdown for an enabled guest agent that needs the selected platform integration.
        if ($guest_agent_enable and $guest_agent_package != undef) {
          # Relax kernel lockdown for the enabled guest-agent integration.
          $security_lockdown_correct = 'none'
        } else {
          # Retain the requested lockdown mode when no compatibility override is needed.
          $security_lockdown_correct = $security_lockdown_requested
        }
      }
    }
  } elsif ($security_lockdown_requested != 'none') {
    # Retain the requested lockdown mode when no compatibility override is needed.
    $security_lockdown_correct = $security_lockdown_requested
  } else {
    # Keep integrity lockdown when Secure Boot prevents disabling it.
    $security_lockdown_correct = 'integrity'
  }

  # Get IP versions
  case $ip_version {
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

  # Install extra packages when Ubuntu
  case $kernel_type {
    'generic': {
      # Install generic kernel
      package { 'linux-generic':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }

      # Remove raspi kernel
      package { ['linux-raspi', 'linux-image-raspi', 'linux-headers-raspi']:
        ensure  => purged,
        require => Package['linux-generic'],
      }

      # Install generic HWE kernel
      if ($os_name == 'Ubuntu' and $os_version != '26.04') {
        package { ["linux-image-generic-hwe-${os_version}", "linux-headers-generic-hwe-${os_version}"]:
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
        }
      }
    }
    'raspi': {
      # Install raspi kernel
      package { 'linux-raspi':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }

      # Remove generic kernel
      package { ['linux-generic', 'linux-image-generic', 'linux-headers-generic']:
        ensure          => purged,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Package['linux-raspi'],
      }
    }
    default: {
      # Other kernel selections do not require a specialized kernel package.
    }
  }

  # Create group for hugetlb only when hugepages is given
  if ($systemd_enable and $hugepages > 0) {
    # Set variable 
    $hugepages_shm_group = 7000

    # Install libhugetlbfs package
    package { 'libhugetlbfs-bin':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Remove group 
    group { 'hugetlb':
      ensure  => present,
      gid     => $hugepages_shm_group,
      require => Package['libhugetlbfs-bin'],
    }

    # Create drop in for dev-hugepages mount
    basic_settings::systemd_drop_in { 'hugetlb_hugepages':
      target_unit => 'dev-hugepages.mount',
      mount       => {
        'Options' => "mode=1770,gid=${hugepages_shm_group}",
      },
      require     => Group['hugetlb'],
    }

    # Create systemd service. Keep /dev visible because hugeadm may inspect the hugetlbfs mount at /dev/hugepages.
    basic_settings::systemd_service { 'dev-hugepages-shmmax':
      description => 'Hugespages recommended shmmax service',
      service     => {
        'ExecStart'               => '/usr/bin/hugeadm --set-recommended-shmmax',
        'LockPersonality'         => 'true',
        'MemoryDenyWriteExecute'  => 'true',
        'NoNewPrivileges'         => 'true',
        'PrivateTmp'              => 'true',
        'ProtectClock'            => 'true',
        'ProtectHome'             => 'true',
        'ProtectHostname'         => 'true',
        'ProtectKernelLogs'       => 'true',
        'ProtectSystem'           => 'full',
        'RestrictSUIDSGID'        => 'true',
        'SystemCallArchitectures' => 'native',
        'Type'                    => 'oneshot',
        'UMask'                   => '0077',
      },
      unit        => stdlib::merge($unit_failure, {
          'Requires' => 'dev-hugepages.mount',
          'After'    => 'dev-hugepages.mount',
      }),
      install     => {
        'WantedBy' => 'dev-hugepages.mount',
      },
    }

    # Reload sysctl deamon
    exec { 'kernel_sysctl_reload':
      command     => '/usr/bin/bash -c "/usr/bin/systemctl start dev-hugepages-shmmax.service && /usr/sbin/sysctl --system"',
      refreshonly => true,
    }
  } else {
    # Set variable
    $hugepages_shm_group = 0

    # Install libhugetlbfs package
    package { 'libhugetlbfs-bin':
      ensure => purged,
    }

    # Remove group 
    group { 'hugetlb':
      ensure  => absent,
      require => Package['libhugetlbfs-bin'],
    }

    # Remove drop in for dev-hugepages mount
    if (defined(Package['systemd'])) {
      basic_settings::systemd_drop_in { 'hugetlb_hugepages':
        ensure      => absent,
        target_unit => 'dev-hugepages.mount',
        require     => Group['hugetlb'],
      }
    }

    # Reload sysctl deamon
    exec { 'kernel_sysctl_reload':
      command     => '/usr/sbin/sysctl --system',
      refreshonly => true,
    }
  }

  # Remove unnecessary packages
  package { ['apport', 'installation-report', 'linux-tools-common', 'pemmican-common', 'plymouth', 'thermald', 'upower']:
    ensure => purged,
  }

  # Install system tools with consistent package settings.
  ensure_packages(
    [
      'coreutils',
      'findutils',
      'grep',
      'lsb-release',
      'lsof',
      'kmod',
      'sed',
      'usbutils',
      'util-linux',
    ],
    {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    },
  )

  # Create sysctl config
  file { '/etc/sysctl.conf':
    ensure  => file,
    content => template('basic_settings/kernel/sysctl.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Exec['kernel_sysctl_reload'],
  }

  # Create sysctl config
  file { '/etc/sysctl.d':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    force   => true,
    purge   => true,
    recurse => true,
    notify  => Exec['kernel_sysctl_reload'],
  }

  # Create sysctl network config
  file { '/etc/sysctl.d/90-network.conf':
    ensure  => file,
    content => template('basic_settings/kernel/sysctl/network.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Exec['kernel_sysctl_reload'],
  }

  # Create sysctl memory config
  file { '/etc/sysctl.d/90-memory.conf':
    ensure  => file,
    content => template('basic_settings/kernel/sysctl/memory.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Exec['kernel_sysctl_reload'],
  }

  # Create symlink
  file { '/etc/sysctl.d/99-sysctl.conf':
    ensure => 'link',
    owner  => 'root',
    group  => 'root',
    target => '/etc/sysctl.conf',
    force  => true,
    notify => Exec['kernel_sysctl_reload'],
  }

  # Set apparmor state
  if (defined(Package['apparmor'])) {
    # Enable AppArmor in the kernel command line when its package is declared.
    $apparmor_enable = true
  } else {
    # Disable AppArmor in the kernel command line when its package is not declared.
    $apparmor_enable = false
  }

  # Get CPU processor
  if (empty($facts['processors']['models'])) {
    # Use an empty CPU description when the model fact is unavailable.
    $cpu_processor = ''
  } else {
    # Use the first processor model to identify the CPU family.
    $cpu_processor = $facts['processors']['models'][0]
  }

  # Set CPU manufacturer
  if ($cpu_processor =~ 'AMD') {
    # Select AMD-specific CPU tuning.
    $cpu_manufacturer = 'amd'
  } elsif ($cpu_processor =~ 'Intel') {
    # Select Intel-specific CPU tuning.
    $cpu_manufacturer = 'intel'
  } else {
    # Leave the CPU family unset when no known vendor matches.
    $cpu_manufacturer = undef
  }

  # Set CPU settings
  if (!$facts['is_virtual']) {
    # Get settings
    $cpu_governor_correct = $cpu_governor
    case $cpu_governor_correct {
      'performance': {
        case $cpu_manufacturer {
          'amd', 'intel': {
            # Apply the physical-host performance profile for supported AMD and Intel CPUs.
            $cpu_boost = 1
            $cpu_idle_max_cstate = 1
            $cpu_pstate = 'passive'
          }
          default: {
            # Leave performance overrides unset for an unrecognized CPU family.
            $cpu_boost = undef
            $cpu_idle_max_cstate = undef
            $cpu_pstate = undef
          }
        }
      }
      default: {
        # Leave performance-specific overrides unset for the other CPU governors.
        $cpu_boost = undef
        $cpu_idle_max_cstate = undef
        $cpu_pstate = undef
      }
    }

    # Check if boot value is given
    if ($cpu_boost != undef) {
      # Escape the CPU boost value before embedding it in the guard script.
      $cpu_boost_shell = stdlib::shell_escape($cpu_boost)
      $cpu_boost_check_script = "if [ ! -f /sys/devices/system/cpu/cpufreq/boost ]; then exit 1; fi; if [ \$(cat /sys/devices/system/cpu/cpufreq/boost) -eq ${cpu_boost_shell} ]; then exit 1; else exit 0; fi" # lint:ignore:140chars

      # Escape the complete guard script before passing it to bash -c.
      $cpu_boost_check_script_shell = stdlib::shell_escape($cpu_boost_check_script)
      exec { 'kernel_cpu_boost':
        command => "/usr/bin/bash -c 'echo \"1\" > /sys/devices/system/cpu/cpufreq/boost'",
        onlyif  => "/usr/bin/bash -c ${cpu_boost_check_script_shell}",
      }
    }
  } else {
    # Set some settings
    $cpu_governor_corect = undef
    $cpu_boost = undef
    $cpu_idle_max_cstate = undef
    $cpu_pstate = undef
  }

  # Check if we have hardware that is passthrough
  if ($hardware_passthrough_correct) {
    # Install firmware packages
    if ($facts['secure_boot_enabled']) {
      package { ['fwupd', 'fwupd-signed']:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    } else {
      package { 'fwupd':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Set fwupd-refresh 
    service { 'fwupd-refresh.timer':
      ensure  => true,
      enable  => true,
      require => Package['fwupd'],
    }
  } else {
    # Remove firmware packages
    package { ['fwupd', 'fwupd-signed', 'rpi-eeprom-update']:
      ensure => purged,
    }
  }

  # Install ram disk package
  case $ram_disk_package {
    'dracut': {
      # Install packages
      $ram_disk_require = ['dracut', 'dracut-core']
      package {['dracut', 'dracut-core']:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }

      # Remove unused packages
      package {['initramfs-tools', 'initramfs-tools-bin', 'initramfs-tools-core']:
        ensure  => purged,
        require => Package['dracut-core'],
      }
    }
    'initramfs': {
      # Install packages 
      if ($os_name == 'Ubuntu') {
        # Use the Ubuntu 24.04 initramfs dependency set for that release.
        if ($os_version == '24.04') {
          # Include the split initramfs binary package in Ubuntu 24.04 rebuild ordering.
          $ram_disk_require = ['dhcpcd-base', 'initramfs-tools', 'initramfs-tools-bin', 'initramfs-tools-core']
          package { $ram_disk_require:
            ensure          => installed,
            install_options => ['--no-install-recommends', '--no-install-suggests'],
          }
        } else {
          # Order initramfs rebuilds after the DHCP helper and core initramfs packages.
          $ram_disk_require = ['dhcpcd-base', 'initramfs-tools', 'initramfs-tools-core']
          package { $ram_disk_require:
            ensure          => installed,
            install_options => ['--no-install-recommends', '--no-install-suggests'],
          }
        }
      } else {
        # Order initramfs rebuilds after the DHCP helper and core initramfs packages.
        $ram_disk_require = ['dhcpcd-base', 'initramfs-tools', 'initramfs-tools-core']
        package { $ram_disk_require:
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
        }
      }

      # Remove unused packages
      package {['dracut', 'dracut-core']:
        ensure  => purged,
        require => Package['initramfs-tools-core'],
      }
    }
    default: {
      # The public enum restricts this selector to the supported initramfs implementations.
    }
  }

  # Set boot options
  case $kernel_type {
    'raspi': {
      file { '/boot/firmware/config.txt':
        ensure  => file,
        content => template('basic_settings/kernel/boot.txt'),
        owner   => 'root',
        group   => 'root',
        mode    => '0755', # Important
        require => Package[$ram_disk_require],
      }

      # Kernel params
      $ip_version_v6_disable = bool2str($ip_version_v6, '0', '1')
      file { '/boot/firmware/cmdline.txt':
        ensure  => file,
        content => template('basic_settings/kernel/cmdline.txt'),
        owner   => 'root',
        group   => 'root',
        mode    => '0755', # Important
        require => Package[$ram_disk_require],
      }

      # Purge bootloaders
      package { ['grub2-common', 'systemd-boot']:
        ensure => purged,
      }

      # No bootloader
      $bootloader_packages = []
    }
    default: {
      # Setup bootloader
      case $bootloader {
        'grub': {
          # Set boot loader packages
          $bootloader_packages = ['/usr/sbin/update-grub']

          # Install package
          package { 'grub2-common':
            ensure          => installed,
            install_options => ['--no-install-recommends', '--no-install-suggests'],
            require         => Package['initramfs-tools-core'],
          }

          # Remove unnecessary packages
          package { 'systemd-boot':
            ensure  => purged,
            require => Package['grub2-common'],
          }

          # Reload sysctl deamon
          exec { 'kernel_grub_update':
            command     => '/usr/sbin/update-grub',
            refreshonly => true,
          }

          # Create custom grub config
          file { '/etc/default/grub':
            ensure  => file,
            content => template('basic_settings/kernel/grub'),
            owner   => 'root',
            group   => 'root',
            mode    => '0600',
            notify  => Exec['kernel_grub_update'],
          }
        }
        default: {
          # Avoid bootloader package dependencies when no supported bootloader is selected.
          $bootloader_packages = []
        }
      }
    }
  }

  # Create list of packages that is suspicious
  $suspicious_packages = flatten($bootloader_packages, [
    '/bin/su',
    '/usr/bin/depmod',
    '/usr/bin/kmod',
    '/usr/bin/lsmod',
    '/usr/bin/lsusb',
    '/usr/bin/usb-devices',
    '/usr/bin/usbhid-dump',
    '/usr/bin/usbreset',
    '/usr/sbin/insmod',
    '/usr/sbin/lsmod',
    '/usr/sbin/modinfo',
    '/usr/sbin/modprobe',
    '/usr/sbin/rmmod',
  ])
  $suspicious_packages_root = [
    '/usr/bin/kmod',
  ]

  # Setup TCP
  case $tcp_congestion_control {
    'bbr': {
      exec { 'tcp_congestion_control':
        command => '/usr/bin/printf "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" > /etc/sysctl.d/20-tcp_congestion_control.conf; chmod 600 /etc/sysctl.d/20-tcp_congestion_control.conf; sysctl -p /etc/sysctl.d/20-tcp_congestion_control.conf', # lint:ignore:140chars
        onlyif  => ['test ! -f /etc/sysctl.d/20-tcp_congestion_control.conf', 'test 4 -eq $(cat /boot/config-$(uname -r) | grep -c -E \'CONFIG_TCP_CONG_BBR|CONFIG_NET_SCH_FQ\')'], # lint:ignore:140chars
      }
    }
    default: {
      exec { 'tcp_congestion_control':
        command => '/usr/bin/rm /etc/sysctl.d/20-tcp_congestion_control.conf',
        onlyif  => '[ -e /etc/sysctl.d/20-tcp_congestion_control.conf ]',
        notify  => Exec['kernel_sysctl_reload'],
      }
    }
  }

  # Improve kernel I/O without storing root-exec state in a predictable /tmp path.
  $kernel_io_device_script = 'dev=$(/usr/bin/lsblk -oMOUNTPOINT,PKNAME -P -M | /usr/bin/sed -n "s/^MOUNTPOINT=\"\/\" PKNAME=\"\([^\"]*\)\".*/\1/p" | /usr/bin/sed "s/[0-9]*$//" | /usr/bin/sed -n "1p")' # lint:ignore:140chars
  $kernel_io_command_script = "${kernel_io_device_script}; [ -n \"\$dev\" ] || exit 0; [ -w \"/sys/block/\${dev}/queue/scheduler\" ] || exit 0; /usr/bin/printf %s none > \"/sys/block/\${dev}/queue/scheduler\"" # lint:ignore:140chars
  $kernel_io_check_script = "${kernel_io_device_script}; [ -n \"\$dev\" ] || exit 1; [ -r \"/sys/block/\${dev}/queue/scheduler\" ] || exit 1; if /usr/bin/grep -q '\\[none\\]' \"/sys/block/\${dev}/queue/scheduler\"; then exit 1; fi; exit 0" # lint:ignore:140chars

  # Escape the complete scripts once before passing them to bash -c.
  $kernel_io_command_shell = stdlib::shell_escape($kernel_io_command_script)
  $kernel_io_check_shell = stdlib::shell_escape($kernel_io_check_script)
  exec { 'kernel_io':
    command => "/usr/bin/bash -c ${kernel_io_command_shell}",
    onlyif  => "/usr/bin/bash -c ${kernel_io_check_shell}",
  }

  # Activate transparent hugepage modus
  exec { 'kernel_transparent_hugepage':
    command => "/usr/bin/bash -c 'echo \"madvise\" > /sys/kernel/mm/transparent_hugepage/enabled'",
    onlyif  => '/usr/bin/bash -c "if [ $(grep -c \'\\[madvise\\]\' /sys/kernel/mm/transparent_hugepage/enabled) -eq 0 ]; then exit 0; fi; exit 1"', # lint:ignore:140chars
  }

  # Activate transparent hugepage defrag
  exec { 'kernel_transparent_hugepage_defrag':
    command => "/usr/bin/bash -c 'echo \"madvise\" > /sys/kernel/mm/transparent_hugepage/defrag'",
    onlyif  => '/usr/bin/bash -c "if [ $(grep -c \'\\[madvise\\]\' /sys/kernel/mm/transparent_hugepage/defrag) -eq 0 ]; then exit 0; fi; exit 1"', # lint:ignore:140chars
  }

  # Kernel Multi-Gen LRU
  if ($mglru_active) {
    exec { 'kernel_mglru':
      command => "/usr/bin/bash -c 'echo \"y\" > /sys/kernel/mm/lru_gen/enabled'",
      onlyif  => '/usr/bin/bash -c "if [ $(grep -c \'0x0003\|0x0007\' /sys/kernel/mm/lru_gen/enabled) -eq 0 ]; then exit 0; fi; exit 1"',
    }
  } else {
    exec { 'kernel_mglru':
      command => "/usr/bin/bash -c 'echo \"n\" > /sys/kernel/mm/lru_gen/enabled'",
      onlyif  => '/usr/bin/bash -c "if [ $(grep -c \'0x0000\' /sys/kernel/mm/lru_gen/enabled) -eq 0 ]; then exit 0; fi; exit 1"',
    }
  }

  # Kernel Multi-Gen LRU thrashing prevention
  # Escape the MGLRU value before writing it and checking the current kernel state.
  $mglru_min_ttl_ms_shell = stdlib::shell_escape($mglru_min_ttl_ms_correct)
  $mglru_min_ttl_ms_check_script = "if [ \$(grep -c ${mglru_min_ttl_ms_shell} /sys/kernel/mm/lru_gen/min_ttl_ms) -eq 0 ]; then exit 0; fi; exit 1" # lint:ignore:140chars

  # Escape the complete guard script before passing it to bash -c.
  $mglru_min_ttl_ms_check_script_shell = stdlib::shell_escape($mglru_min_ttl_ms_check_script)
  exec { 'kernel_mglru_min_ttl_ms':
    command => "/usr/bin/printf %s ${mglru_min_ttl_ms_shell} > /sys/kernel/mm/lru_gen/min_ttl_ms",
    onlyif  => "/usr/bin/bash -c ${mglru_min_ttl_ms_check_script_shell}",
    require => Exec['kernel_mglru'],
  }

  # Kernel security lockdown
  # Escape lockdown values before writing them and checking the current kernel state.
  $security_lockdown_correct_shell = stdlib::shell_escape($security_lockdown_correct)
  $security_lockdown_pattern_shell = stdlib::shell_escape("\\[${security_lockdown_correct}\\]")
  $security_lockdown_check_script = "if [ \$(grep -c ${security_lockdown_pattern_shell} /sys/kernel/security/lockdown) -eq 0 ]; then exit 0; fi; exit 1" # lint:ignore:140chars

  # Escape the complete guard script before passing it to bash -c.
  $security_lockdown_check_script_shell = stdlib::shell_escape($security_lockdown_check_script)
  exec { 'kernel_security_lockdown':
    command => "/usr/bin/printf %s ${security_lockdown_correct_shell} > /sys/kernel/security/lockdown",
    onlyif  => "/usr/bin/bash -c ${security_lockdown_check_script_shell}",
  }

  # Guest agent
  if ($guest_agent_package != undef) {
    # Install or remove the available guest agent according to the requested state.
    if ($guest_agent_enable) {
      # Keep policy flags last even when caller options contain duplicate or conflicting flags.
      package { $guest_agent_package:
        ensure          => installed,
        install_options => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
      }
    } else {
      package { $guest_agent_package:
        ensure => purged,
      }
    }
  }

  # Setup monitoring
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    # Both checks use awk; coreutils and sed are installed with the kernel tools above.
    ensure_packages(['dash', 'mawk'], {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    })

    # Register memory pressure monitoring next to kernel memory tuning.
    basic_settings::monitoring_custom { 'memory_pressure':
      friendly => 'Memory pressure',
      content  => template('basic_settings/monitoring/check_memory_pressure'),
      require  => Package['coreutils', 'dash', 'mawk', 'sed'],
    }

    # Reegister USB monitoring
    basic_settings::monitoring_custom { 'usb':
      friendly => 'USB',
      content  => template('basic_settings/monitoring/check_usb'),
      require  => Package['coreutils', 'dash', 'mawk', 'sed'],
    }
  }

  # Create kernel rules
  if (defined(Package['auditd'])) {
    # Exclude executables already covered by the root audit rules.
    $suspicious_filter = $suspicious_packages - $suspicious_packages_root
    basic_settings::security_audit { 'kernel':
      rules                    => [
        '# Injection',
        '# These rules watch for code injection by the ptrace facility.',
        '# This could indicate someone trying to do something bad or just debugging',
        '-a always,exit -F arch=b32 -S ptrace -F a0=0x4 -F key=code_injection',
        '-a always,exit -F arch=b64 -S ptrace -F a0=0x4 -F key=code_injection',
        '-a always,exit -F arch=b32 -S ptrace -F a0=0x5 -F key=data_injection',
        '-a always,exit -F arch=b64 -S ptrace -F a0=0x5 -F key=data_injection',
        '-a always,exit -F arch=b32 -S ptrace -F a0=0x6 -F key=register_injection',
        '-a always,exit -F arch=b64 -S ptrace -F a0=0x6 -F key=register_injection',
        '-a always,exit -F arch=b32 -S ptrace -F key=tracing',
        '-a always,exit -F arch=b64 -S ptrace -F key=tracing',
        '# Kernel parameters',
        '-a always,exit -F arch=b32 -F path=/usr/sbin/sysctl -F perm=x -F key=sysctl',
        '-a always,exit -F arch=b64 -F path=/usr/sbin/sysctl -F perm=x -F key=sysctl',
        '-a always,exit -F arch=b32 -F path=/etc/sysctl.conf -F perm=wa -F key=sysctl',
        '-a always,exit -F arch=b64 -F path=/etc/sysctl.conf -F perm=wa -F key=sysctl',
        '-a always,exit -F arch=b32 -F path=/etc/sysctl.d -F perm=wa -F key=sysctl',
        '-a always,exit -F arch=b64 -F path=/etc/sysctl.d -F perm=wa -F key=sysctl',
        '# Kernel modules',
        '-a always,exit -F arch=b32 -S init_module -S delete_module -F key=kernel_modules',
        '-a always,exit -F arch=b64 -S init_module -S delete_module -F key=kernel_modules',
        '# Modprobe configuration',
        '-a always,exit -F arch=b32 -F path=/etc/modprobe.conf -F perm=wa -F key=modprobe',
        '-a always,exit -F arch=b64 -F path=/etc/modprobe.conf -F perm=wa -F key=modprobe',
        '-a always,exit -F arch=b32 -F path=/etc/modprobe.d -F perm=wa -F key=modprobe',
        '-a always,exit -F arch=b64 -F path=/etc/modprobe.d -F perm=wa -F key=modprobe',
      ],
      rule_suspicious_packages => $suspicious_filter,
      order                    => 15,
    }

    # Retain login attribution when auditing privileged kernel tools.
    basic_settings::security_audit { 'kernel-root':
      rule_suspicious_packages => $suspicious_packages_root,
      rule_options             => ['-F auid!=unset'],
      order                    => 10,
    }

    # Ignore current working directory records
    basic_settings::security_audit { 'kernel-cwd':
      rules => ['-a always,exclude -F msgtype=CWD'], # Special case, don't use never,exit
      order => 1,
    }
  }
}
