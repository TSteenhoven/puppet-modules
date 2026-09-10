# @summary Creates one backend fragment for a systemd service check.
#
# lint:ignore:140chars
# This internal helper is called by `basic_settings::monitoring_service` after the parent type has resolved package, friendly-name, and script-path settings.
# lint:endignore
# It renders one OpenITCOCKPIT custom-check fragment per service unit.
#
# @example Internal use through basic_settings::monitoring_service
#   basic_settings::monitoring_service { 'mail':
#     services => ['postfix'],
#   }
#
# @param friendly
#   Base friendly name resolved by the parent monitoring defined type.
#
# @param package
#   Monitoring backend package. Currently only `openitcockpit` creates output.
#
# @param parent_name
#   Parent check name used to build the generated script section name.
#
# @param script_path
#   Absolute path to the shared systemd service check script.
#
# @param active_days
#   Optional active-day expression passed to the check script.
#
# @param active_windows
#   Optional active-window expression passed to the check script.
#
# @param ensure
#   Controls whether the backend fragment is present or omitted.
#
# @param parent_force
#   Forces use of the parent friendly name and script name even when the checked service title differs from the parent title.
#
# @api private
define basic_settings::monitoring_service_part (
  String                    $friendly,
  String                    $package,
  String                    $parent_name,
  String                    $script_path,
  Optional[String]          $active_days    = undef,
  Optional[String]          $active_windows = undef,
  Enum['present', 'absent'] $ensure         = present,
  Boolean                   $parent_force   = false,
) {
  case $package {
    'openitcockpit': {
      # Create fragment for plugin
      if ($ensure == present) {
        # Build some values
        if ($parent_name == $name or $parent_force) {
          # Keep the parent check's label and executable identity.
          $friendly_correct = $friendly
          $script_name = "check_${parent_name}"
        } else {
          # Distinguish each child service in its label and executable identity.
          $friendly_correct = "${friendly} ${name}"
          $script_name = "check_${parent_name}_${name}"
        }

        # Build active window parameter
        if ($active_windows != undef) {
          # Restrict the check to the supplied active time window.
          $script_active_window = "-W ${active_windows} "
        } else {
          # Omit a time-window restriction when none is supplied.
          $script_active_window = ''
        }

        # Build active days parameter
        if ($active_days != undef) {
          # Restrict the check to the supplied active days.
          $script_active_days = "-D ${active_days} "
        } else {
          # Omit a day restriction when none is supplied.
          $script_active_days = ''
        }

        # Add fragment
        concat::fragment { "monitoring_service_part_${name}":
          target  => '/etc/openitcockpit-agent/customchecks.ini',
          content => "\n[${script_name}] # ${friendly_correct}\ncommand = ${script_path} ${script_active_window}${script_active_days}${name}.service\ninterval = 300\ntimeout = 10\nenabled = true\n", # lint:ignore:140chars
          order   => '10',
        }
      }
    }
    default: {
      # Other selections do not emit OpenITCOCKPIT registration fragments.
    }
  }
}
