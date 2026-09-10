# @summary Installs and configures vnStat traffic accounting.
#
# lint:ignore:140chars
# This class installs vnStat, builds `/etc/vnstat.conf` and `/etc/vnstat-monitoring.conf` through concat, and integrates the daemon with the local `basic_settings` systemd and logrotate helpers when those helpers are already present in the catalog. The default configuration lets vnstatd add newly discovered interfaces automatically so a host receives traffic accounting without a per-interface resource.
# lint:endignore
#
# @example Install vnStat with the default configuration
#   class { 'vnstat': }
#
# @example Configure global bandwidth and 95th percentile monitoring defaults
#   class { 'vnstat':
#     bandwidth_max => 1000,
#     p95_critical  => 900,
#     p95_warning   => 700,
#   }
#
# @param bandwidth_max
# lint:ignore:140chars
#   Global `MaxBandwidth` value in Mbit/s. The default `0` renders `MaxBandwidth 0`, which disables vnStat's global reject limit and prevents the monitoring check from using the global value as a positive capacity fallback. Set a positive value when all monitored interfaces can safely share the same fallback capacity.
# lint:endignore
#
# @param nice_level
# lint:ignore:140chars
#   Positive nice value rendered as a negative systemd `Nice` setting for `vnstat.service`. The default `8` makes the daemon prefer responsiveness without running at the highest priority.
# lint:endignore
#
# @param p95_critical
# lint:ignore:140chars
#   Optional global 95th percentile critical threshold in Mbit/s for the monitoring check. `undef` leaves the global critical threshold unset.
# lint:endignore
#   Interface-specific `vnstat::ethernet` values override this default.
#
# @param p95_warning
#   Optional global 95th percentile warning threshold in Mbit/s for the monitoring check. `undef` leaves the global warning threshold unset.
#   Interface-specific `vnstat::ethernet` values override this default.
#
# @param target
#   `basic_settings::systemd` target suffix that should bind to `vnstat.service` when the shared systemd target ladder is present.
#
# @api public
class vnstat (
  Optional[Integer[0, 50000]] $bandwidth_max = 0,
  Integer                     $nice_level    = 8,
  Optional[Integer[1]]        $p95_critical  = undef,
  Optional[Integer[1]]        $p95_warning   = undef,
  String                      $target        = 'services',
) {
  # Keep generated monitoring configuration valid before the check consumes it.
  if ($p95_warning != undef and $p95_critical != undef and $p95_critical < $p95_warning) {
    # Reject thresholds that would report critical before warning.
    $fail_text = 'vnstat p95_critical must be greater than or equal to p95_warning.'
  } else {
    # Allow bandwidth monitoring when the supplied thresholds are ordered correctly.
    $fail_text = undef
  }

  # Build the complete configuration only after validating the supplied settings.
  if ($fail_text == undef) {
    # Share monitoring availability between service notifications and check registration.
    $monitoring_enable = defined(Class['basic_settings::monitoring'])

    # Install vnstat
    package { 'vnstat':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Check if we have systemd
    if (defined(Package['systemd'])) {
      # Disable service
      service { 'vnstat':
        ensure  => undef,
        enable  => false,
        require => Package['vnstat'],
      }

      # Reload systemd daemon
      exec { 'vnstat_systemd_daemon_reload':
        command     => '/usr/bin/systemctl daemon-reload',
        refreshonly => true,
        require     => Package['systemd'],
      }

      # Get unit
      if ($monitoring_enable) {
        # Route unit failures through the configured monitoring notification service.
        $unit = {
          'OnFailure' => 'notify-failed@%i.service',
        }
      } else {
        # Leave unit failure hooks empty when monitoring is unavailable.
        $unit = {}
      }

      # Create drop in for vnstat service
      basic_settings::systemd_drop_in { 'vnstat_settings':
        target_unit   => 'vnstat.service',
        unit          => $unit,
        service       => {
          'Nice'         => "-${nice_level}",
        },
        daemon_reload => 'vnstat_systemd_daemon_reload',
        require       => Package['vnstat'],
      }

      # Create drop in for x target
      if (defined(Class['basic_settings::systemd'])) {
        basic_settings::systemd_drop_in { 'vnstat_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-${target}.target",
          unit          => {
            'BindsTo'   => 'vnstat.service',
          },
          daemon_reload => 'vnstat_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-${target}"],
        }
      }
    } else {
      # Enable service
      service { 'vnstat':
        ensure  => true,
        enable  => true,
        require => Package['vnstat'],
      }
    }

    # Build vnStat configuration from the default template and optional fragments.
    concat { '/etc/vnstat.conf':
      owner   => 'root',
      group   => 'root',
      mode    => '0600', # Only root
      notify  => Service['vnstat'],
      require => Package['vnstat'],
    }

    # Place the base daemon settings before optional interface configuration fragments.
    concat::fragment { 'vnstat_config_default':
      target  => '/etc/vnstat.conf',
      content => template('vnstat/vnstat.conf'),
      order   => '10',
    }

    # Check if logrotate package exists
    if (defined(Package['logrotate'])) {
      basic_settings::io_logrotate { 'vnstat':
        path           => '/var/log/vnstat/vnstat.log',
        frequency      => 'weekly',
        compress_delay => true,
        create_group   => 'vnstat',
        create_user    => 'vnstat',
        rotate_copy    => true,
      }
    }

    # Create monitoring configuration from the default template and optional fragments.
    concat { '/etc/vnstat-monitoring.conf':
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      require => Package['vnstat'],
    }

    # Store monitoring-only defaults separately so vnStat receives only native directives.
    concat::fragment { 'vnstat_monitoring_config_default':
      target  => '/etc/vnstat-monitoring.conf',
      content => template('vnstat/monitoring.conf'),
      order   => '10',
    }

    # Create service check
    if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
      basic_settings::monitoring_custom { 'vnstat_interfaces':
        ensure   => present,
        source   => 'puppet:///modules/vnstat/check_vnstat_interfaces',
        friendly => 'vnStat interfaces',
        timeout  => 60,
        require  => Concat['/etc/vnstat-monitoring.conf'],
      }
    }
  } else {
    fail($fail_text)
  }
}
