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

            /* Check if pro is enabled */
            if ($enable) {

            } else {
                service { ['ubuntu-advantage.service', 'esm-cache.service']:
                    ensure      => stopped,
                    enable      => false
                }
            }
        }
    }
}
