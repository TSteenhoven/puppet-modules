# @summary Manages Ubuntu Pro client packages and optional monitoring tooling.
#
# This class applies only on Ubuntu. It installs Ubuntu Pro client packages, preserves the installer-managed ESM APT
# hook, optionally installs Landscape monitoring tooling, and adds logrotate coverage when logrotate is available.
#
# @example Install Ubuntu Pro client packages
#   class { 'basic_settings::pro':
#     enable => true,
#   }
#
# @param enable
#   Indicates that Ubuntu Pro support is desired. When combined with snap support the class ensures Pro client tooling
#   is installed.
#
# @param monitoring_enable
#   Installs Landscape monitoring packages when `true` and `enable` is also `true`; purges them otherwise.
#
# @api public
class basic_settings::pro (
  Boolean $enable            = false,
  Boolean $monitoring_enable = false,
) {
  # Get OS name
  case $facts['os']['name'] {
    'Ubuntu': {
      # Install advantage tools
      package { ['ubuntu-advantage-tools', 'ubuntu-pro-client']:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
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
      if (defined(Class['basic_settings::monitoring'])) {
        # Reuse the package class's Snap setting for the Pro monitoring integration.
        $snap_enable = $basic_settings::packages::snap_enable
      } else {
        # Omit Snap integration from the standalone Pro path.
        $snap_enable = false
      }

      # Check if pro is enabled
      if ($enable and $monitoring_enable) {
        # Install monitoring tools
        package { ['landscape-common']:
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
        }
      } else {
        # Remove monitoring tools
        package { ['landscape-common']:
          ensure => purged,
        }
      }

      # Install Ubuntu Pro client tools only for enabled integration with Snap support.
      if ($enable and $snap_enable) {
        # Install advantage tools
        package { ['ubuntu-advantage-tools', 'ubuntu-pro-client']:
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
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
    default: {
      # Ubuntu Pro does not apply to other operating systems.
    }
  }
}
