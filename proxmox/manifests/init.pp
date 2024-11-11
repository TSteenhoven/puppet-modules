class proxmox () {
  case $basic_settings::os_name {
    'bookworm': {
      $kernel = '6.2'
    }
    default:  {
      $kernel = undef
    }
  }

  if ($kernel) {
    # Install kernel
    package { "pve-kernel-${kernel}":
      ensure        => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Reboot server
  reboot { 'proxmox_pre_kernel_after':
    subscribe => Package["pve-kernel-${kernel}"],
  }

  # Install proxmox
  package { ['proxmox-ve', 'open-iscsi']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
    require         => Reboot['pre_kernel_after'],
  }

  # Reload systemd deamon
  exec { 'proxmox_update_grub':
    command     => 'update-grub',
    refreshonly => true,
    require     => Package['proxmox-ve'],
  }

  # Remove linux kernel
  package { ['linux-image*', 'os-prober']:
    ensure  => absent,
    require => Package['proxmox-ve'],
    notify  => Exec['proxmox_update_grub'],
  }
}
}
