# @summary Registers a Mirth Connect check with the OpenITCOCKPIT agent.
#
# This class adds a custom OpenITCOCKPIT check for Mirth Connect through the shared monitoring helper. It requires
# `openitcockpit::agent` so the agent directory and custom-check configuration exist.
#
# @example Enable the Mirth Connect check
#   include openitcockpit::agent
#   include openitcockpit::agent_mirth_connect
#
# @param ensure
#   Controls whether the custom monitoring check is present or absent.
#
# @param package
#   Optional monitoring package override passed to `basic_settings::monitoring_custom`.
#
# @api public
class openitcockpit::agent_mirth_connect (
  Enum['present', 'absent'] $ensure  = present,
  Optional[String]          $package = undef,
) {
  # Require the agent parent before registering the Mirth Connect check.
  if (defined(Class['openitcockpit::agent'])) {
    # Detect systemd before registering the Mirth Connect agent integration.
    $systemd_enable = defined(Package['systemd'])
    basic_settings::monitoring_custom { 'mirth_connect':
      ensure   => $ensure,
      package  => $package,
      friendly => 'Mirth Connect',
      content  => template('openitcockpit/agent/check_mirth_connect'),
      timeout  => 60,
    }
  } else {
    fail('The openitcockpit::agent class must be included before using the openitcockpit::agent_mirth_connect defined type.')
  }
}
