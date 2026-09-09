# @summary Installs PHP 8 core packages and selected extensions.
#
# lint:ignore:140chars
# This class installs the selected PHP 8 minor version, common/opcache packages, optional extension packages, and default shared files used by PHP CLI/FPM consumers. It is deliberately package-focused; CLI and FPM service configuration lives in `php8::cli` and `php8::fpm`.
# lint:endignore
#
# @example Install PHP 8.2 with common web extensions
#   class { 'php8':
#     curl  => true,
#     mysql => true,
#     xml   => true,
#     zip   => true,
#   }
#
# @param apcu Enables the APCu extension package.
# @param bcmath Enables the BCMath extension package.
# @param bz2 Enables the bzip2 extension package.
# @param curl Enables the cURL extension package.
# @param gd Enables the GD extension package.
# @param gearman Enables the Gearman extension package.
# @param gmp Enables the GMP extension package.
# @param imagick Enables the ImageMagick extension package.
# @param imap Enables the IMAP extension package.
# @param intl Enables the Intl extension package.
# @param ldap Enables the LDAP extension package.
# @param mbstring Enables the mbstring extension package.
# @param mcrypt Enables the mcrypt extension package.
# @param minor_version PHP 8 minor version to install, rendered as `php8.<minor>`.
# @param msgpack Enables the MessagePack extension package.
# @param mysql Enables the MySQL extension package.
# @param readline Enables the readline extension package.
# @param redis Enables the Redis extension package.
# @param rrd Enables the RRD extension package.
# @param skip_default_files Skips shared default PHP files when multiple PHP versions are managed.
# @param soap Enables the SOAP extension package.
# @param sqlite3 Enables the SQLite extension package.
# @param sybase Enables the Sybase extension package.
# @param uploadprogress Enables the uploadprogress extension package.
# @param xdebug Enables the Xdebug extension package.
# @param xml Enables the XML extension package.
# @param xmlrpc Enables the XML-RPC extension package.
# @param zip Enables the ZIP extension package.
#
# @api public
class php8 (
  Boolean $apcu               = false,
  Boolean $bcmath             = false,
  Boolean $bz2                = false,
  Boolean $curl               = false,
  Boolean $gd                 = false,
  Boolean $gearman            = false,
  Boolean $gmp                = false,
  Boolean $imagick            = false,
  Boolean $imap               = false,
  Boolean $intl               = false,
  Boolean $ldap               = false,
  Boolean $mbstring           = false,
  Boolean $mcrypt             = false,
  Integer $minor_version      = 2,
  Boolean $msgpack            = false,
  Boolean $mysql              = false,
  Boolean $readline           = false,
  Boolean $redis              = false,
  Boolean $rrd                = false,
  Boolean $skip_default_files = false,
  Boolean $soap               = false,
  Boolean $sqlite3            = false,
  Boolean $sybase             = false,
  Boolean $uploadprogress     = false,
  Boolean $xdebug             = false,
  Boolean $xml                = false,
  Boolean $xmlrpc             = false,
  Boolean $zip                = false,
) {
  # Install common php packages,
  package { ["php8.${minor_version}", "php8.${minor_version}-common", "php8.${minor_version}-opcache"]:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  if ($apcu) {
    package { "php8.${minor_version}-apcu":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($bcmath) {
    package { "php8.${minor_version}-bcmath":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($bz2) {
    package { "php8.${minor_version}-bz2":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($curl) {
    package { "php8.${minor_version}-curl":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($gd) {
    package { "php8.${minor_version}-gd":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($gearman) {
    package { "php8.${minor_version}-gearman":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($gmp) {
    package { "php8.${minor_version}-gmp":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($imagick) {
    package { "php8.${minor_version}-imagick":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($imap) {
    package { "php8.${minor_version}-imap":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($intl) {
    package { "php8.${minor_version}-intl":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($ldap) {
    package { "php8.${minor_version}-ldap":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($mbstring) {
    package { "php8.${minor_version}-mbstring":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($mcrypt) {
    package { "php8.${minor_version}-mcrypt":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($msgpack) {
    package { "php8.${minor_version}-msgpack":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($mysql) {
    package { "php8.${minor_version}-mysql":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($readline) {
    package { "php8.${minor_version}-readline":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($redis) {
    package { "php8.${minor_version}-redis":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($rrd) {
    package { "php8.${minor_version}-rrd":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($soap) {
    package { "php8.${minor_version}-soap":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($sqlite3) {
    package { "php8.${minor_version}-sqlite3":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($sybase) {
    package { "php8.${minor_version}-sybase":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($uploadprogress) {
    package { "php8.${minor_version}-uploadprogress":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($xdebug) {
    package { "php8.${minor_version}-xdebug":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($xml) {
    package { "php8.${minor_version}-xml":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($xmlrpc) {
    package { "php8.${minor_version}-xmlrpc":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }
  if ($zip) {
    package { "php8.${minor_version}-zip":
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Skip only when you have multiple PHP versions
  if (!$skip_default_files) {
    # Custom extensions
    file { '/usr/lib/php/custom_extensions':
      ensure  => directory,
      path    => '/usr/lib/php/custom_extensions',
      owner   => 'root',
      group   => 'root',
      mode    => '0755', # Import, otherwise non-root users will not be able to use PHP
      require => Package["php8.${minor_version}-common"],
    }

    # Extra packages
    file { '/usr/lib/php/extras':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755', # Import, otherwise non-root users will not be able to use PHP
      require => Package["php8.${minor_version}-common"],
    }

    # Create php browser list file
    file { '/usr/lib/php/extras/lite_php_browscap.ini':
      ensure  => file,
      source  => 'puppet:///modules/php8/extra/lite_php_browscap-ini',
      owner   => 'root',
      group   => 'root',
      mode    => '0644', # Import, otherwise non-root users will not be able to use PHP
      require => File['/usr/lib/php/extras'],
    }
  }
}
