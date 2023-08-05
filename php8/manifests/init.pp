
class php8(
        $bcmath             = false,
        $bzip2              = false,
        $curl               = false,
        $gd                 = false,
        $gmp                = false,
        $imagick            = false,
        $intl               = false,
        $ldap               = false,
        $mbstring           = false,
        $mcrypt             = false,
        $msgpack            = false,
        $mysql              = false,
        $readline           = false,
        $soap               = false,
        $sqlite3            = false,
        $sybase             = false,
        $xdebug             = false,
        $xml                = false,
        $zip                = false,
        $minor_version      = '2',
        $skip_default_files = false
    ) {

    /* Install common php packages,  */
    package { ["php8.${minor_version}-common", "php8.${minor_version}-opcache"]:
        ensure  => installed
    }

    if ($bcmath) {
        package { "php8.${minor_version}-bcmath": ensure => installed }
    }
    if ($bzip2) {
        package { "php8.${minor_version}-bz2": ensure => installed }
    }
    if ($curl) {
        package { "php8.${minor_version}-curl": ensure => installed }
    }
    if ($gd) {
        package { "php8.${minor_version}-gd": ensure => installed }
    }
    if ($gmp) {
        package { "php8.${minor_version}-gmp": ensure => installed }
    }
    if ($imagick) {
        package { "php8.${minor_version}-imagick": ensure => installed }
    }
    if ($intl) {
        package { "php8.${minor_version}-intl": ensure => installed }
    }
    if ($ldap) {
        package { "php8.${minor_version}-ldap": ensure => installed }
    }
    if ($mbstring) {
        package { "php8.${minor_version}-mbstring": ensure => installed }
    }
    if ($mcrypt) {
        package { "php8.${minor_version}-mcrypt": ensure => installed }
    }
    if ($msgpack) {
        package { "php8.${minor_version}-msgpack": ensure => installed }
    }
    if ($mysql) {
        package { "php8.${minor_version}-mysql": ensure => installed }
    }
    if ($readline) {
        package { "php8.${minor_version}-readline": ensure => installed }
    }
    if ($soap) {
        package { "php8.${minor_version}-soap": ensure => installed }
    }
    if ($sqlite3) {
        package { "php8.${minor_version}-sqlite3": ensure => installed }
    }
    if ($sybase) {
        package { "php8.${minor_version}-sybase": ensure => installed }
    }
    if ($xdebug) {
        package { "php8.${minor_version}-xdebug": ensure => installed }
    }
    if ($xsl) {
        package { "php8.${minor_version}-xsl": ensure => installed }
    }
    if ($xml) {
        package { "php8.${minor_version}-xml": ensure => installed }
    }
    if ($zip) {
        package { "php8.${minor_version}-zip": ensure => installed }
    }

    if (!$skip_default_files) {
        /* Custom extensions */
        file { '/usr/lib/php/custom_extensions':
            ensure  => directory,
            path    => '/usr/lib/php/custom_extensions',
            owner   => 'root',
            group   => 'root',
            mode    => '0755', # Import, otherwise non-root users will not be able to use PHP
            require => Package["php8.${minor_version}-common"]
        }

        /* Available php mods */
        file { '/etc/php/mods-available':
            ensure  => link,
            target  => "/etc/php/8.${minor_version}/mods-available",
            force   => true,
            require => Package["php8.${minor_version}-common"]
        }

        /* Extra packages */
        file { '/usr/lib/php/extras':
            ensure  => directory,
            owner   => 'root',
            group   => 'root',
            mode    => '0755', # Import, otherwise non-root users will not be able to use PHP
            require => Package["php8.${minor_version}-common"]
        }

        /* Create php browser list file */
        file { '/usr/lib/php/extras/lite_php_browscap.ini':
            ensure  => present,
            source  => 'puppet:///modules/php8/extra/lite_php_browscap-ini',
            owner   => 'root',
            group   => 'root',
            mode    => '0644', # Import, otherwise non-root users will not be able to use PHP
            require => File['/usr/lib/php/extras']
        }

        /* Create APT config */
        file { '/etc/apt/apt.conf.d/05php':
            ensure  => present,
            source  => 'puppet:///modules/php8/apt-bash',
            owner   => 'root',
            group   => 'root',
            mode    => '0644', # Import, otherwise non-root users will not be able to use PHP
            require => File['/etc/php/mods-available']
        }
    }
}

