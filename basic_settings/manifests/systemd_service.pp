# @summary Manages a generated systemd service unit and optional monitoring.
#
# This defined type writes `/etc/systemd/system/<title>.service` from the shared template, controls the service
# enablement state, registers service monitoring when requested, and automatically adds an npm audit check for Node.js
# services with a known working directory. Service hardening is supplied explicitly by the caller through the `service`
# hash.
#
# @example Create a hardened oneshot service
#   basic_settings::systemd_service { 'example':
#     description => 'Example task',
#     service     => {
#       'ExecStart' => '/usr/local/sbin/example',
#       'Type'      => 'oneshot',
#     },
#   }
#
# @param description
#   Human-readable service description rendered into the unit.
#
# @param daemon_reload
#   Exec resource title notified after the service file changes.
#
# @param enable
#   Controls whether the service is enabled when `ensure` is `present`.
#
# @param ensure
#   Controls whether the generated service unit is present or absent.
#
# @param install
#   Key/value settings rendered into the `[Install]` section.
#
# @param monitoring_active_days
#   Optional active-day expression passed to generated service monitoring.
#
# @param monitoring_active_windows
#   Optional active-window expression passed to generated service monitoring.
#
# @param monitoring_enable
#   Enables generated monitoring when set to `true`. `undef` leaves monitoring absent.
#
# @param monitoring_package
#   Monitoring backend package passed to `basic_settings::monitoring_service`.
#
# @param service
#   Key/value settings rendered into the `[Service]` section.
#
# @param service_subscribe
#   Optional resources subscribed by the Puppet `service` resource.
#
# @param unit
#   Key/value settings rendered into the `[Unit]` section.
#
# @api public
define basic_settings::systemd_service (
  String                    $description,
  String                    $daemon_reload             = 'systemd_daemon_reload',
  Boolean                   $enable                    = true,
  Enum['present', 'absent'] $ensure                    = present,
  Hash                      $install                   = {
    'WantedBy'  => 'multi-user.target',
  },
  Optional[String]          $monitoring_active_days    = undef,
  Optional[String]          $monitoring_active_windows = undef,
  Optional[Boolean]         $monitoring_enable         = undef,
  Optional[String]          $monitoring_package        = undef,
  Hash                      $service                   = {},
  Optional[Array]           $service_subscribe         = undef,
  Hash                      $unit                      = {},
) {
  # Check if systemd package is not defined
  if (!defined(Package['systemd'])) {
    package { 'systemd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Create systemd service file
  file { "/etc/systemd/system/${name}.service":
    ensure  => $ensure,
    content => template('basic_settings/systemd/service'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644', # See issue https://github.com/systemd/systemd/issues/770
    notify  => Exec[$daemon_reload],
    require => Package['systemd'],
  }

  # Set service
  if ($ensure == present) {
    # Enable service
    service { $name:
      enable    => $enable,
      require   => File["/etc/systemd/system/${name}.service"],
      subscribe => $service_subscribe,
    }

    # Check if we need to monitoring this service
    if ($monitoring_enable != undef and $monitoring_package != 'none') {
      # Translate the explicit monitoring toggle into check presence or removal.
      $monitoring_ensure = $monitoring_enable ? { true => 'present', default => absent }
    } else {
      # Remove the service check when monitoring is not selected for this backend.
      $monitoring_ensure = absent
    }
  } elsif ($monitoring_package != 'none') {
    # Remove the service check when monitoring is not selected for this backend.
    $monitoring_ensure = absent
  }

  # Setup monitoring for this service
  basic_settings::monitoring_service { $name:
    ensure         => $monitoring_ensure,
    package        => $monitoring_package,
    active_windows => $monitoring_active_windows,
    active_days    => $monitoring_active_days,
  }

  # Check if service is using node executable in ExecStart
  if ('ExecStart' in $service and $service['ExecStart'] =~ String and $service['ExecStart'] =~ /^(?:node|\.{1,2}\/node|\/(?:[^\/\s]+\/)+node)\s+/) { # lint:ignore:140chars
    # Require a working directory before registering the Node.js dependency audit.
    if ('WorkingDirectory' in $service and $service['WorkingDirectory'] =~ String) {
      basic_settings::monitoring_npm_audit { $name:
        ensure  => $monitoring_ensure,
        dir     => $service['WorkingDirectory'],
        package => $monitoring_package,
      }
    } else {
      basic_settings::monitoring_npm_audit { $name:
        ensure  => absent,
        dir     => '',
        package => $monitoring_package,
      }
    }
  }
}
