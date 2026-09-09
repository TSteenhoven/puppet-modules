# @summary Adds vnStat configuration for one ethernet interface.
#
# lint:ignore:140chars
# This defined type appends optional concat fragments to `/etc/vnstat.conf` and `/etc/vnstat-monitoring.conf`. Use it for interface-specific configuration that should stay outside the global vnStat defaults, such as a known technical speed cap for `MaxBW<interface>` or 95th percentile monitoring thresholds.
# lint:endignore
#
# @example Configure a known maximum bandwidth for one interface
#   vnstat::ethernet { 'ens192':
#     bandwidth_max => 1000,
#   }
#
# @example Override 95th percentile thresholds for one interface
#   vnstat::ethernet { 'wan-uplink':
#     interface    => 'ens224',
#     p95_critical => 8000,
#     p95_warning  => 6000,
#   }
#
# @param bandwidth_max
# lint:ignore:140chars
#   Optional value for `MaxBW<interface>` in Mbit/s. Set this to the real technical interface speed, not a purchased traffic bundle or alert limit.
# lint:endignore
#   `undef` omits the interface-specific vnStat bandwidth fragment.
#
# @param ensure
#   Controls whether the concat fragment is emitted. `absent` omits the fragment from the compiled configuration.
#
# @param interface
#   Interface name used in generated vnStat directives. `undef` uses the resource title.
#
# @param order
#   Concat fragment order. The default `50` places interface fragments after the base vnStat configuration.
#
# @param p95_critical
#   Optional 95th percentile critical threshold in Mbit/s for this interface.
# lint:ignore:140chars
#   `undef` inherits the class-level threshold when one is configured. The monitoring fragment uses the effective inherited value when either 95th percentile threshold is configured for the interface or class.
# lint:endignore
#
# @param p95_warning
#   Optional 95th percentile warning threshold in Mbit/s for this interface.
# lint:ignore:140chars
#   `undef` inherits the class-level threshold when one is configured. The monitoring fragment uses the effective inherited value when either 95th percentile threshold is configured for the interface or class.
# lint:endignore
#
# @api public
define vnstat::ethernet (
  Optional[Integer[0, 50000]] $bandwidth_max = undef,
  Enum['present', 'absent']   $ensure        = 'present',
  Optional[String[1]]         $interface     = undef,
  String[1]                   $order         = '50',
  Optional[Integer[1]]        $p95_critical  = undef,
  Optional[Integer[1]]        $p95_warning   = undef,
) {
  if (defined(Class['vnstat'])) {
    if ($interface == undef) {
      $interface_correct = $name
    } else {
      $interface_correct = $interface
    }

    # The monitoring config is whitespace-delimited, so interface names must stay single-token.
    if ($interface_correct !~ /\s/) {
      # Check if warning threshold is undefined
      if ($p95_warning == undef) {
        $p95_warning_correct = $vnstat::p95_warning
      } else {
        $p95_warning_correct = $p95_warning
      }

      # Check if critical threshold is undefined
      if ($p95_critical == undef) {
        $p95_critical_correct = $vnstat::p95_critical
      } else {
        $p95_critical_correct = $p95_critical
      }

      if ($ensure == present) {
        if ($bandwidth_max != undef) {
          concat::fragment { "vnstat_ethernet_${name}":
            target  => '/etc/vnstat.conf',
            content => template('vnstat/ethernet.conf'),
            order   => $order,
            require => Concat['/etc/vnstat.conf'],
          }
        }

        if ($p95_warning_correct != undef or $p95_critical_correct != undef) {
          # Keep generated monitoring configuration valid before the check consumes it.
          if ($p95_warning_correct != undef and $p95_critical_correct != undef and $p95_critical_correct < $p95_warning_correct) {
            $fail_text = 'vnstat p95_critical must be greater than or equal to p95_warning.'
          } else {
            $fail_text = undef
          }

          # Create monitoring configuration from the default template and optional fragments.
          if ($fail_text == undef) {
            concat::fragment { "vnstat_monitoring_ethernet_${name}":
              target  => '/etc/vnstat-monitoring.conf',
              content => template('vnstat/monitoring.conf'),
              order   => $order,
              require => Concat['/etc/vnstat-monitoring.conf'],
            }
          } else {
            fail($fail_text)
          }
        }
      }
    } else {
      fail("vnstat::ethernet[${name}] interface names must not contain whitespace.")
    }
  } else {
    fail('The vnstat class must be included before using the vnstat::ethernet defined type.')
  }
}
