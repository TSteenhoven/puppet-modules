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

    /* Set variables from parent */
    $minor_version = $php8::minor_version
    $skip_default_files = $php8::skip_default_files

    /* Set listen path */
    if ($listen) {
        $listen_path = $listen
    } elsif ($skip_default_files) {
        $listen_path = "/run/php/php8.${minor_version}-fpm.sock"
    } else {
        $listen_path = '/run/php/php-fpm.sock'
    }

    /* Create config file */
    file { "/etc/php/8.${minor_version}/fpm/pool.d/${name}.conf":
        ensure  => file,
        content => template('php8/fpm-pool.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service["php8.${minor_version}-fpm"],
    }
}
