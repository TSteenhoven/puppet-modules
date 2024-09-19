class basic_settings::pro (
  Boolean $enable = false
) {
  # Get OS name
  case $facts['os']['name'] { #lint:ignore:case_without_default
    'Ubuntu': {
      # Install advantage tools
      package { ['ubuntu-advantage-tools', 'ubuntu-pro-client']:
        ensure => installed,
      }

      # Keep APT config
      file { '/etc/apt/apt.conf.d/20apt-esm-hook.conf':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        replace => false,
        require => Package['ubuntu-pro-client'],
      }

      # Check snap state
      if (defined(Class['basic_settings::message'])) {
        $snap_enable = $basic_settings::packages::snap_enable
      } else {
        $snap_enable = false
      }

      # Check if pro is enabled
      if ($enable and $snap_enable) {} else {
        service { ['ubuntu-advantage.service', 'ua-reboot-cmds.service', 'ua-timer.timer']:
          ensure => stopped,
          enable => false,
        }
      }

      # Check if logrotate package exists
      if (defined(Package['logrotate'])) {
        basic_settings::io_logrotate { 'ubuntu-pro-client':
          path      => '/var/log/ubuntu-advantage*.log',
          frequency => 'monthly',
        }
      }
    }
  }
}
