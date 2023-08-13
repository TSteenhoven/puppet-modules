class php8::cli(
        $ini_settings       = [],
        $composer_enable    = true
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
        ensure  => file,
        content => template('php8/settings-template.ini'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644' # Import, otherwise non-root users will not be able to use PHP
    }

    /* Check if we need to install composer */
    if ($composer_enable) {
        /* Install composer */
        exec { "php8_${minor_version}_composer_fetch_installer":
            command => '/usr/bin/curl -s -L https://getcomposer.org/installer -o /tmp/composer-setup.php',
            unless  => '[ -e /usr/local/bin/composer ]',
            require =>  [Package['curl'], Package["php8.${minor_version}-cli"]]
        }
        ->
        exec { "php8_${minor_version}_composer_fetch_hash":
            command => '/usr/bin/curl -s -L https://composer.github.io/installer.sig -o /tmp/composer_hash',
            onlyif  => 'test -f /tmp/composer-setup.php',
            require => [Package['curl'], Package["php8.${minor_version}-cli"]]
        }
        ->
        exec { "php8_${minor_version}_composer_fetch_check_hash":
            command => 'php -r "if (hash_file(\'SHA384\', \'/tmp/composer-setup.php\') !== trim(file_get_contents(\'/tmp/composer_hash\'))) { unlink\'/tmp/composer-setup.php\'); unlink(\'/tmp/composer_hash\'); exit(1); }"',
            onlyif  => ['test -f /tmp/composer-setup.php', 'test -f /tmp/composer_hash'],
            require => Package["php8.${minor_version}-cli"],
        }
        ->
        exec {  "php8_${minor_version}_composer_install":
            environment => 'COMPOSER_HOME=/usr/local/bin',
            command => 'php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer',
            onlyif  => 'test -f /tmp/composer-setup.php',
            require => Package["php8.${minor_version}-cli"]
        }
        ->
        exec { "php8_${minor_version}_composer_cleanup":
            command => 'php -r "unlink\'/tmp/composer-setup.php\'); unlink(\'/tmp/composer_hash\');"',
            onlyif  => ['test -f /tmp/composer-setup.php', 'test -f /tmp/composer_hash'],
            require => Package["php8.${minor_version}-cli"]
        }
    }
}
