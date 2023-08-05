define php8::fpm_pool(
        $user                   = 'www-data',
        $group                  = 'www-data',

        $listen                 = undef,
        $listen_user            = $user,
        $listen_group           = $group,
        $listen_mode            = '0660',

        $pm                     = 'dynamic',
        $pm_max_children        = 5,
        $pm_start_servers       = 2,
        $pm_min_spare_servers   = 1,
        $pm_max_spare_servers   = 3,
        $pm_procidle_timeout    = '10s',
        $pm_max_requests        = 0
    ) {

    /* Get minor version from PHP init */
    $minor_version = $php8::minor_version

    /* Set listen path */
    if ($listen) {
        $listen_path = $listen
    } else {
        $listen_path = "/run/php/php8.${minor_version}-fpm.sock"
    }

    /* Create config file */
    file { "/etc/php/8.${minor_version}/fpm/pool.d/${name}.conf":
        ensure  => present,
        content => template('php8/fpm-pool.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service["php8.${minor_version}-fpm"],
    }
}
