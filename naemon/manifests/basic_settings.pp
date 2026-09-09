# @summary Creates a Naemon host entry for a host managed by basic_settings.
#
# lint:ignore:140chars
# This defined type wraps `naemon::host` with a standard passive firewall check used for hosts that report through the repository's basic monitoring model.
# lint:endignore
#
# @example Add a basic_settings host to Naemon
#   naemon::basic_settings { 'web01':
#     address => '192.0.2.10',
#   }
#
# @param address
#   Address rendered into the generated host definition.
#
# @param ensure
#   Controls whether the generated host configuration is present or absent.
#
# @param friendly
#   Optional display name for the host. `undef` lets the host template use the resource title.
#
# @api public
define naemon::basic_settings (
  String                    $address,
  Enum['present', 'absent'] $ensure   = present,
  Optional[String]          $friendly = undef,
) {
  # Create host
  naemon::host { $name:
    ensure   => $ensure,
    address  => $address,
    friendly => $friendly,
    checks   => {
      'firewall' => {
        active_checks          => {
          enable => false,
        },
        passive_checks_enabled => true,
        process_perf_data      => true,
      },
    },
  }
}
