# @summary Installs Proxmox VE packages and kernel cleanup on Debian 12.
#
# lint:ignore:140chars
# This class expects `basic_settings` platform detection to be available. It installs the selected Proxmox kernel for supported releases, schedules a reboot after kernel installation, installs `proxmox-ve` and `open-iscsi`, removes generic Linux kernel packages, and refreshes GRUB after kernel cleanup.
# lint:endignore
# Missing platform context or a platform other than Debian 12 fails before creating kernel-dependent resources.
#
# @example Install Proxmox after the basic server baseline
#   include basic_settings
#   include proxmox
#
# @api public
class proxmox () {
  # Platform detection is owned by basic_settings; dependent resources must not escape that contract.
  if (defined(Class['basic_settings'])) {
    case $basic_settings::os_name {
      'bookworm': {
        $kernel = '6.2'
      }
      default:  {
        $kernel = undef
      }
    }

    if ($kernel) {
      # The selected kernel provides the package anchor for the staged reboot.
      package { "pve-kernel-${kernel}":
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }

      # Reboot after the selected kernel package changes.
      reboot { 'proxmox_pre_kernel_after':
        subscribe => Package["pve-kernel-${kernel}"],
      }

      # Stage the platform packages after the kernel reboot contract.
      package { ['proxmox-ve', 'open-iscsi']:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Reboot['proxmox_pre_kernel_after'],
      }

      # Regenerate GRUB when conflicting kernel packages are removed.
      exec { 'proxmox_update_grub':
        command     => 'update-grub',
        refreshonly => true,
        require     => Package['proxmox-ve'],
      }

      # Notify GRUB only after removing packages that conflict with the selected PVE kernel.
      package { ['linux-image*', 'os-prober']:
        ensure  => absent,
        require => Package['proxmox-ve'],
        notify  => Exec['proxmox_update_grub'],
      }
    } else {
      fail('proxmox supports only Debian 12 (bookworm) with a selected PVE kernel.')
    }
  } else {
    fail('proxmox requires the basic_settings class before selecting a kernel.')
  }
}
