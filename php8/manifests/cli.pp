# @summary Installs PHP CLI configuration and optional Composer.
#
# lint:ignore:140chars
# This class requires `php8`, installs the matching CLI package, writes CLI INI settings, optionally sets the default `php` alternative, and can install Composer after verifying the installer signature in a root-only temporary directory.
# lint:endignore
#
# @example Configure PHP CLI with Composer
#   class { 'php8::cli':
#     ini_settings => { 'memory_limit' => '256M' },
#   }
#
# @param composer_enable
#   Downloads, verifies, and installs Composer when `true`.
#
# @param ini_settings
#   Hash of INI settings rendered into the CLI custom settings file. Must not include module-managed PHP INI settings such as `expose_php`.
#
# @api public
class php8::cli (
  Boolean $composer_enable = true,
  Hash    $ini_settings    = {},
) {
  # Require the PHP parent before selecting the CLI version and rendering INI settings.
  if (defined(Class['php8'])) {
    # Merge given init settings with default settings
    $correct_ini_settings = stdlib::merge({
        'date.timezone' => $basic_settings::server_timezone,
    }, $ini_settings)

    # Reject module-managed PHP INI settings before the custom settings template is rendered.
    $reserved_ini_setting_names = ['expose_php']
    $reserved_ini_settings = $correct_ini_settings.keys.filter |$setting_key| { $setting_key in $reserved_ini_setting_names }
    if (empty($reserved_ini_settings)) {
      # Get minor version from PHP init
      $minor_version = $php8::minor_version

      # Set up PHP 8 CLI
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

      # Update the default PHP executable only when default-file management is enabled.
      if (!$php8::skip_default_files) {
        # Escape the PHP binary path before passing it to update-alternatives.
        $php_cli_bin_shell = stdlib::shell_escape("/usr/bin/php8.${minor_version}")

        # Change PHP version
        exec { 'php_set_default_version':
          command     => "/usr/bin/update-alternatives --set php ${php_cli_bin_shell}",
          refreshonly => true,
          require     => Package["php8.${minor_version}"],
          subscribe   => Package["php8.${minor_version}"],
        }
      }

      # Check if we need to install composer
      if ($composer_enable) {
        # Download, verify, and install Composer in a root-only temp directory that is always removed.
        exec { "php8_${minor_version}_composer_install":
          environment => 'COMPOSER_HOME=/usr/local/bin',
          command     => "/usr/bin/bash -c 'set -e; umask 077; tmpdir=\$(/usr/bin/mktemp -d /root/php8-composer.XXXXXX) || exit 1; trap \"rm -rf \\\"\$tmpdir\\\"\" EXIT; /usr/bin/curl -fsSL https://getcomposer.org/installer -o \"\$tmpdir/composer-setup.php\"; /usr/bin/curl -fsSL https://composer.github.io/installer.sig -o \"\$tmpdir/composer_hash\"; php -r \"if (hash_file(\\\"SHA384\\\", \\\"\$tmpdir/composer-setup.php\\\") !== trim(file_get_contents(\\\"\$tmpdir/composer_hash\\\"))) { exit(1); }\"; php \"\$tmpdir/composer-setup.php\" --quiet --install-dir=/usr/local/bin --filename=composer'", # lint:ignore:140chars
          unless      => '[ -e /usr/local/bin/composer ]',
          require     => [Package['curl'], Package["php8.${minor_version}-cli"], Exec['php_set_default_version']],
        }
      }
    } else {
      # List reserved INI keys in the validation error before rejecting the configuration.
      $reserved_ini_settings_text = join($reserved_ini_settings, ', ')
      fail("php8::cli ini_settings must not include module-managed PHP INI settings: ${reserved_ini_settings_text}.")
    }
  } else {
    fail('The php8 class must be included before using the php8::cli defined type.')
  }
}
