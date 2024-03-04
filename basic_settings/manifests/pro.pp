class basic_settings::pro(
    $enable = false
) {
    /* Get OS name */
    case $operatingsystem {
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
                service { 'ubuntu-advantage.service':
                    ensure      => stopped,
                    enable      => false
                }
            }
        }
    }
}
