class php8::cli(
        $ini_settings = []
    ) {

    /* Get minor version from PHP init */
    $minor_version = $php8::minor_version

    /* Setip PHP 8 CLI */
    package { "php8.${minor_version}-cli":
        ensure  => installed,
        require => Class['php8'],
    }
    ->
    file { "/etc/php/8.${minor_version}/cli/conf.d/99-custom-settings.ini":
        ensure  => present,
        content => template('php8/settings-template.ini'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644' # Import, otherwise non-root users will not be able to use PHP
    }
}
