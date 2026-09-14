# @summary Installs Certbot and manages shared Let's Encrypt client defaults.
#
# This class installs Certbot, adjusts the `certbot.service` systemd priority when systemd is present, derives the
# notification email address, configures logrotate for Certbot logs when available, and writes
# `/etc/letsencrypt/cli.ini`.
#
# @example Install Certbot defaults
#   include letsencrypt
#
# @param mail_to
#   Email address used by the Certbot CLI configuration. `undef` inherits monitoring mail when available, otherwise uses
#   `root`.
#
# @param nice_level
#   Positive nice value converted to a negative service priority in the systemd drop-in. The default is 8.
#
# @api public
class letsencrypt (
  Optional[String] $mail_to    = undef,
  Integer          $nice_level = 8,
) {
  # Share monitoring availability between service notifications and the certificate contact.
  $monitoring_enable = defined(Class['basic_settings::monitoring'])

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
    if ($monitoring_enable) {
      # Route unit failures through the configured monitoring notification service.
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }
    } else {
      # Leave unit failure hooks empty when monitoring is unavailable.
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
    # Use the monitoring contact when available, otherwise keep the local root contact.
    if ($monitoring_enable) {
      # Reuse the central monitoring contact for certificate notifications.
      $mail_to_correct = $basic_settings::monitoring::mail_to
    } else {
      # Send certificate notifications to root when no monitoring contact is available.
      $mail_to_correct = 'root'
    }
  } else {
    # Use the caller's certificate notification address.
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
    # Retain Certbot's own backup limit when logrotate does not manage its logs.
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
