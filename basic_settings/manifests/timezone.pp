# @summary Manages timezone and systemd-timesyncd NTP configuration.
#
# lint:ignore:140chars
# This class installs and enables systemd-timesyncd when systemd is available, renders `/etc/systemd/timesyncd.conf`, removes competing NTP packages, adds a monitoring check when monitoring is active, and delegates timezone setting to the vendored `timezone` module.
# lint:endignore
#
# @example Set the server timezone
#   class { 'basic_settings::timezone':
#     timezone => 'Europe/Amsterdam',
#   }
#
# @param timezone
#   Timezone name passed to the `timezone` module, such as `UTC` or `Europe/Amsterdam`.
#
# @param install_options
# lint:ignore:140chars
#   Additional APT options; an empty array adds no caller options. Mandatory no-recommends and no-suggests flags are appended without deduplication so they remain effective.
# lint:endignore
#
# @param ntp_extra_pools
#   Additional NTP pools prepended to the OS default pool list.
#
# @api public
class basic_settings::timezone (
  String $timezone,
  Array  $install_options = [],
  Array  $ntp_extra_pools = [],
) {
  # Check if systemd is installed
  if (defined(Package['systemd'])) {
    # Reload systemd deamon
    exec { 'systemd_timezone_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Install package
    # Keep policy flags last even when caller options contain duplicate or conflicting flags.
    package { 'systemd-timesyncd':
      ensure          => installed,
      install_options => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
    }

    # Get OS name
    case $facts['os']['name'] {
      'Ubuntu': {
        # Combine extra NTP pools with the Ubuntu defaults.
        $ntp_all_pools = flatten($ntp_extra_pools, [
          '0.ubuntu.pool.ntp.org',
          '1.ubuntu.pool.ntp.org',
          '2.ubuntu.pool.ntp.org',
          '3.ubuntu.pool.ntp.org',
        ])
      }
      'Debian': {
        # Combine extra NTP pools with the Debian defaults.
        $ntp_all_pools = flatten($ntp_extra_pools, [
          '0.debian.pool.ntp.org',
          '1.debian.pool.ntp.org',
          '2.debian.pool.ntp.org',
          '3.debian.pool.ntp.org',
        ])
      }
      default: {
        # Leave the pool list empty when no distribution default is defined.
        $ntp_all_pools = []
      }
    }

    # Systemd NTP settings
    $ntp_list = join($ntp_all_pools, ' ')

    # Create systemd timesyncd config
    file { '/etc/systemd/timesyncd.conf':
      ensure  => file,
      content => template('basic_settings/systemd/timesyncd.conf'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644', # Important
      notify  => Exec['systemd_timezone_daemon_reload'],
      require => Package['systemd-timesyncd'],
    }

    # Ensure that systemd-timesyncd is always running
    service { 'systemd-timesyncd':
      ensure    => running,
      enable    => true,
      require   => File['/etc/systemd/timesyncd.conf'],
      subscribe => File['/etc/systemd/timesyncd.conf'],
    }

    # Create service check
    if (defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none') {
      basic_settings::monitoring_custom { 'systemd_timesyncd':
        source => 'puppet:///modules/basic_settings/monitoring/check_systemd_timesyncd',
      }
    }

    # Remove unnecessary packages
    package { ['chrony', 'ntp', 'ntpdate', 'ntpsec']:
      ensure  => purged,
      require => Package['systemd-timesyncd'],
    }
  }

  # Set timezoen
  class { 'timezone':
    timezone    => $timezone,
    require     => File['/etc/systemd/timesyncd.conf']
  }
}
