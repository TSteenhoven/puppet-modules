# @summary Installs Certbot and manages shared Let's Encrypt client defaults.
#
# lint:ignore:140chars
# This class installs Certbot, adjusts the `certbot.service` systemd priority when systemd is present, derives the notification email address, configures logrotate for Certbot logs when available, and writes `/etc/letsencrypt/cli.ini`.
# lint:endignore
#
# @example Install Certbot defaults
#   include letsencrypt
#
# @param mail_to
#   Email address used by the Certbot CLI configuration. `undef` inherits monitoring mail when available, otherwise uses `root`.
#
# @param nice_level
#   Positive nice value converted to a negative service priority in the systemd drop-in. The default is 8.
#
# @api public
class letsencrypt (
  Optional[String] $mail_to    = undef,
  Integer          $nice_level = 8,
) {
  # Install certbot
  package { 'certbot':
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Check if we have systemd
  if (defined(Package['systemd'])) {
    # Reload systemd deamon
    exec { 'letsencrypt_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Get unit
    if (defined(Class['basic_settings::monitoring'])) {
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }
    } else {
      $unit = {}
    }

    # Create drop in for certbot service
    basic_settings::systemd_drop_in { 'letsencrypt_settings':
      target_unit   => 'certbot.service',
      unit          => $unit,
      service       => {
        'Nice'         => "-${nice_level}",
      },
      daemon_reload => 'letsencrypt_systemd_daemon_reload',
      require       => Package['certbot'],
    }
  }

  # Try to get mail adres
  if ($mail_to == undef) {
    if (defined(Class['basic_settings::monitoring'])) {
      $mail_to_correct = $basic_settings::monitoring::mail_to
    } else {
      $mail_to_correct = 'root'
    }
  } else {
    $mail_to_correct = $mail_to
  }

  # Check if logrotate package exists
  if (defined(Package['logrotate'])) {
    basic_settings::io_logrotate { 'certbot':
      path      => '/var/log/letsencrypt/*.log',
      frequency => 'weekly',
    }
    $max_log_backups = 0
  } else {
    $max_log_backups = 30
  }

  # Set config file
  file { '/etc/letsencrypt/cli.ini':
    ensure  => file,
    content => template('letsencrypt/cli.ini'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600', # Only root
    require => Package['certbot'],
  }
}
