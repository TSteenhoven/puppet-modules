class basic_settings::message(
    $server_fdqn    = $fdqn,
    $mail_to        = 'root',
    $mail_package   = 'postfix'
) {

    /* Install package */
    package { ["${mail_package}", 'mailutils']:
        ensure => installed
    }

    /* Enable mail service */
    service { "${mail_package}":
        ensure  => true,
        enable  => true,
        require => Package[$mail_package]
    }

    /* Create systemd service for notification */
    basic_settings::systemd_service { 'notify-failed@':
        description => 'Send systemd notifications to mail',
        service     => {
            'Type'      => 'oneshot',
            'ExecStart' => "/usr/bin/bash -c 'LC_CTYPE=C systemctl status --full %i | /usr/bin/mail -s \"Service %i failed on ${server_fdqn}\" -r \"systemd@${server_fdqn}\" \"${mail_to}\"'",
        },
        require => Package[$mail_package]
    }

    /* Create drop in for notify-failed service */
    basic_settings::systemd_drop_in { "notify-failed_${mail_package}_dependency":
        target_unit     => 'notify-failed@',
        unit            => {
            'Wants' => "${mail_package}.service"
        },
        require         => [Package[$mail_package], Basic_settings::Systemd_service['notify-failed@']]
    }
}