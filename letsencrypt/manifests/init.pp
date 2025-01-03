class letsencrypt (
  Integer           $nice_level = 8,
  Optional[String]  $mail_to    = undef,
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
    if (defined(Class['basic_settings::message'])) {
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
    if (defined(Class['basic_settings::message'])) {
      $mail_to_correct = $basic_settings::message::mail_to
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
