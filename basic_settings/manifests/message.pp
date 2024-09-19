class basic_settings::message (
  String $mail_to        = 'root',
  String $mail_package   = 'postfix',
  String $server_fdqn    = $facts['networking']['fqdn']
) {
  # Install package
  package { [$mail_package, 'mailutils']:
    ensure => installed,
  }

  # Enable mail service
  service { $mail_package:
    ensure  => true,
    enable  => true,
    require => Package[$mail_package],
  }

  if (defined(Package['systemd'])) {
    # Reload systemd deamon
    exec { 'message_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create systemd service for notification
    basic_settings::systemd_service { 'notify-failed@':
      description   => 'Send systemd notifications to mail',
      service       => {
        'Type'      => 'oneshot',
        'ExecStart' => "/usr/bin/bash -c 'LC_CTYPE=C systemctl status --full %i | /usr/bin/mail -s \"Service %i failed on ${server_fdqn}\" -r \"systemd@${server_fdqn}\" \"${mail_to}\"'", #lint:ignore:140chars
      },
      daemon_reload => 'message_systemd_daemon_reload',
      require       => Package[$mail_package],
    }

    # Create drop in for notify-failed service
    basic_settings::systemd_drop_in { "notify-failed_${mail_package}_dependency":
      target_unit   => 'notify-failed@',
      unit          => {
        'Wants' => "${mail_package}.service",
      },
      daemon_reload => 'message_systemd_daemon_reload',
      require       => [Package[$mail_package], Basic_settings::Systemd_service['notify-failed@']],
    }
  }
}
