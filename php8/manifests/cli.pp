class php8::cli (
  Boolean   $composer_enable    = true,
  Hash      $ini_settings       = {}
) {
  # Merge given init settings with default settings
  $correct_ini_settings = stdlib::merge({
      'date.timezone' => $basic_settings::server_timezone,
  }, $ini_settings)

  # Get minor version from PHP init
  $minor_version = $php8::minor_version

  # Setip PHP 8 CLI
  package { "php8.${minor_version}-cli":
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
    require         => Class['php8'],
  }
  -> file { "/etc/php/8.${minor_version}/cli/conf.d/99-custom-settings.ini":
    ensure  => file,
    content => template('php8/settings-template.ini'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644' # Import, otherwise non-root users will not be able to use PHP
  }

  if (!$php8::skip_default_files) {
    # Change PHP version
    exec { 'php_set_default_version':
      command     => "update-alternatives --set php /usr/bin/php8.${minor_version}",
      refreshonly => true,
      require     => Package["php8.${minor_version}"],
      subscribe   => Package["php8.${minor_version}"],
    }
  }

  # Check if we need to install composer
  if ($composer_enable) {
    # Install composer
    exec { "php8_${minor_version}_composer_fetch_installer":
      command => '/usr/bin/curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php',
      unless  => '[ -e /usr/local/bin/composer ]',
      require => [Package['curl'], Package["php8.${minor_version}-cli"], Exec['php_set_default_version']],
    }
    -> exec { "php8_${minor_version}_composer_fetch_hash":
      command => '/usr/bin/curl -fsSL https://composer.github.io/installer.sig -o /tmp/composer_hash',
      onlyif  => 'test -f /tmp/composer-setup.php',
      require => [Package['curl'], Package["php8.${minor_version}-cli"], Exec['php_set_default_version']],
    }
    -> exec { "php8_${minor_version}_composer_fetch_check_hash":
      command => 'php -r "if (hash_file(\'SHA384\', \'/tmp/composer-setup.php\') !== trim(file_get_contents(\'/tmp/composer_hash\'))) { unlink(\'/tmp/composer-setup.php\'); unlink(\'/tmp/composer_hash\'); exit(1); }"', #lint:ignore:140chars
      onlyif  => ['test -f /tmp/composer-setup.php', 'test -f /tmp/composer_hash'],
      require => [Package["php8.${minor_version}-cli"], Exec['php_set_default_version']],
    }
    -> exec { "php8_${minor_version}_composer_install":
      environment => 'COMPOSER_HOME=/usr/local/bin',
      command     => 'php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer',
      onlyif      => 'test -f /tmp/composer-setup.php',
      require     => [Package["php8.${minor_version}-cli"], Exec['php_set_default_version']],
    }
    -> exec { "php8_${minor_version}_composer_cleanup":
      command => 'php -r "unlink(\'/tmp/composer-setup.php\'); unlink(\'/tmp/composer_hash\');"',
      onlyif  => ['test -f /tmp/composer-setup.php', 'test -f /tmp/composer_hash'],
      require => [Package["php8.${minor_version}-cli"], Exec['php_set_default_version']],
    }
  }
}
