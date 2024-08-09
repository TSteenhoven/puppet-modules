class basic_settings::pro(
    Optional[Boolean] $enable = false
) {
    /* Get OS name */
    case $::os['name'] {
        'Ubuntu': {
            /* Install advantage tools */
            package { 'ubuntu-advantage-tools':
                ensure => installed
            }

            /* Check snap state */
            if (defined(Class['basic_settings::message'])) {
                $snap_enable = $basic_settings::packages::snap_enable
            } else {
                $snap_enable = false
            }

            /* Check if pro is enabled */
            if ($enable and $snap_enable) {

            } else {
                service { ['ubuntu-advantage.service', 'ua-reboot-cmds.service', 'ua-timer.timer']:
                    ensure      => stopped,
                    enable      => false
                }
            }
        }
    }
}
