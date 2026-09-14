# @summary Installs and configures PHP-FPM for the selected PHP 8 version.
#
# This class requires `php8`, installs the matching FPM package, disables vendor enablement, applies systemd hardening,
# integrates with Nginx and monitoring when present, owns the FPM global config and pool directory, writes custom INI
# settings, and registers logrotate for the FPM log.
#
# @example Configure PHP-FPM
#   class { 'php8::fpm':
#     ini_settings => { 'memory_limit' => '256M' },
#   }
#
# @param errorlog
#   Optional FPM error log path. `undef` uses the versioned default under `/var/log`.
#
# @param ini_settings
#   Hash of INI settings rendered into the FPM custom settings file. Must not include module-managed PHP INI settings
#   such as `expose_php`.
#
# @param pidfile
#   Optional FPM PID file path. `undef` uses the versioned default under `/run`.
#
# @api public
class php8::fpm (
  Optional[String] $errorlog     = undef,
  Hash             $ini_settings = {},
  Optional[String] $pidfile      = undef,
) {
  # Require the PHP parent before configuring its FPM service.
  if (defined(Class['php8'])) {
    # Merge given init settings with default settings
    if (defined(Class['basic_settings::timezone'])) {
      # Use the central timezone as a PHP default while retaining explicit INI overrides.
      $correct_ini_settings = stdlib::merge({
          'date.timezone' => $basic_settings::timezone::timezone,
      }, $ini_settings)
    } else {
      # Keep the supplied INI settings without adding a central timezone default.
      $correct_ini_settings = $ini_settings
    }

    # Reject module-managed PHP INI settings before the custom settings template is rendered.
    $reserved_ini_setting_names = ['expose_php']
    $reserved_ini_settings = $correct_ini_settings.keys.filter |$setting_key| { $setting_key in $reserved_ini_setting_names }
    if (empty($reserved_ini_settings)) {
      # Get minor version from PHP init
      $minor_version = $php8::minor_version

      # Get correct pid file
      if ($pidfile == undef) {
        # Keep the FPM PID file distinct for the selected PHP minor version.
        $correct_pidfile = "/run/php/php8.${minor_version}-fpm.pid"
      } else {
        # Preserve the caller's FPM PID-file path.
        $correct_pidfile = $pidfile
      }

      # Get correct error file
      if ($errorlog == undef) {
        # Keep the FPM error log distinct for the selected PHP minor version.
        $correct_errorlog = "/var/log/php8.${minor_version}-fpm.log"
      } else {
        # Preserve the caller's FPM error-log path.
        $correct_errorlog = $errorlog
      }

      # Install package
      package { "php8.${minor_version}-fpm":
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => Class['php8'],
      }

      # Disable service
      service { "php8.${minor_version}-fpm":
        ensure  => undef,
        enable  => false,
        require => Package["php8.${minor_version}-fpm"],
      }

      # Reload systemd deamon
      exec { "php8_${minor_version}_systemd_daemon_reload":
        command     => '/usr/bin/systemctl daemon-reload',
        refreshonly => true,
        require     => Package['systemd'],
      }

      # Set PHP-FPM service hardening explicitly, even when newer distro units already ship these settings.
      $default_service = {
        'PrivateDevices'          => 'true',
        'PrivateTmp'              => 'true',
        'ProtectClock'            => 'true',
        'ProtectHome'             => 'true',
        'ProtectHostname'         => 'true',
        'ProtectControlGroups'    => 'true',
        'ProtectKernelLogs'       => 'true',
        'ProtectKernelModules'    => 'true',
        'ProtectKernelTunables'   => 'true',
        'ProtectSystem'           => 'full',
        'RestrictAddressFamilies' => 'AF_INET AF_INET6 AF_NETLINK AF_UNIX',
        'RestrictNamespaces'      => 'true',
        'RestrictRealtime'        => 'true',
        'SystemCallArchitectures' => 'native',
        'UMask'                   => '0077',
      }

      # Check if nginx class exists
      if (defined(Class['nginx'])) {
        # Remove unnecessary package
        package { "libapache2-mod-php8.${minor_version}":
          ensure => purged,
        }

        # Create drop in for nginx service
        basic_settings::systemd_drop_in { 'nginx_php_dependency':
          target_unit   => 'nginx.service',
          unit          => {
            'After'   => "php8.${minor_version}-fpm.service",
            'BindsTo' => "php8.${minor_version}-fpm.service",
          },
          daemon_reload => "php8_${minor_version}_systemd_daemon_reload",
          require       => Package['nginx'],
        }

        # Set service
        $service = stdlib::merge({
            'Nice' => "-${nginx::nice_level}",
        }, $default_service)
      } else {
        # Use the default FPM service settings without an Nginx service dependency.
        $service = $default_service
      }

      # Create service check
      if (defined(Class['basic_settings::monitoring'])) {
        # Route unit failures through the configured monitoring notification service.
        $unit = {
          'OnFailure' => 'notify-failed@%i.service',
        }

        # Register the FPM service check only with an active monitoring backend.
        if ($basic_settings::monitoring::package != 'none') {
          basic_settings::monitoring_service { 'php8':
            friendly => 'PHP8',
            services => ["php8.${minor_version}-fpm"],
          }
        }
      } else {
        # Leave unit failure hooks empty when monitoring is unavailable.
        $unit = {}
      }

      # Create drop in for PHP FPM service
      basic_settings::systemd_drop_in { "php8_${minor_version}_settings":
        target_unit   => "php8.${minor_version}-fpm.service",
        unit          => $unit,
        service       => $service,
        daemon_reload => "php8_${minor_version}_systemd_daemon_reload",
        require       => Package["php8.${minor_version}-fpm"],
      }

      # Create PHP FPM config
      file { "/etc/php/8.${minor_version}/fpm/php-fpm.conf":
        ensure  => file,
        content => template('php8/fpm-global.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service["php8.${minor_version}-fpm"],
        require => Package["php8.${minor_version}-fpm"],
      }

      # Create PHP FPM pool
      file { "/etc/php/8.${minor_version}/fpm/pool.d":
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        purge   => true,
        force   => true,
        recurse => true,
      }

      # Create PHP custom settings
      file { "/etc/php/8.${minor_version}/fpm/conf.d/99-custom-settings.ini":
        ensure  => file,
        content => template('php8/settings-template.ini'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
      }

      # Check if logrotate package exists
      if (defined(Package['logrotate'])) {
        basic_settings::io_logrotate { "php8.${minor_version}-fpm":
          path           => "/var/log/php8.${minor_version}-fpm.log",
          frequency      => 'weekly',
          compress_delay => true,
          rotate_post    => "if [ -x /usr/lib/php/php8.${minor_version}-fpm-reopenlogs ]; then\n\t\t/usr/lib/php/php8.${minor_version}-fpm-reopenlogs;\n\tfi", # lint:ignore:140chars
        }
      }
    } else {
      # List reserved INI keys in the validation error before rejecting the configuration.
      $reserved_ini_settings_text = join($reserved_ini_settings, ', ')
      fail("php8::fpm ini_settings must not include module-managed PHP INI settings: ${reserved_ini_settings_text}.")
    }
  } else {
    fail('The php8 class must be included before using the php8::fpm class type.')
  }
}
