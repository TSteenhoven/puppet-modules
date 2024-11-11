class basic_settings::systemd (
  String              $cluster_id         = 'core',
  String              $default_target     = 'helpers',
  Array               $install_options    = [],
) {
  # Install packages
  package { ['dbus', 'dbus-user-session', 'systemd', 'systemd-cron', 'systemd-sysv', 'libpam-systemd']:
    ensure          => installed,
    install_options => union($install_options, ['--no-install-recommends', '--no-install-suggests']),
  }

  # Remove unnecessary packages
  package { ['anacron', 'cron']:
    ensure  => purged,
    require => Package['systemd-cron'],
  }

  # Reload systemd deamon
  exec { 'systemd_daemon_reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    require     => Package['systemd'],
  }

  # Systemd storage target
  basic_settings::systemd_target { "${cluster_id}-system":
    description    => 'System',
    parent_targets => ['multi-user'],
    allow_isolate  => true,
  }

  # Systemd storage target
  basic_settings::systemd_target { "${cluster_id}-storage":
    description    => 'Storage',
    parent_targets => ["${cluster_id}-system"],
    allow_isolate  => true,
  }

  # Systemd services target
  basic_settings::systemd_target { "${cluster_id}-services":
    description    => 'Services',
    parent_targets => ["${cluster_id}-storage"],
    allow_isolate  => true,
  }

  # Systemd production target
  basic_settings::systemd_target { "${cluster_id}-production":
    description    => 'Production',
    parent_targets => ["${cluster_id}-services"],
    allow_isolate  => true,
  }

  # Systemd helpers target
  basic_settings::systemd_target { "${cluster_id}-helpers":
    description    => 'Helpers',
    parent_targets => ["${cluster_id}-production"],
    allow_isolate  => true,
  }

  # Systemd require services target
  basic_settings::systemd_target { "${cluster_id}-require-services":
    description    => 'Require services',
    parent_targets => ["${cluster_id}-helpers"],
    allow_isolate  => true,
  }

  # Set default target
  exec { 'set_default_target':
    command => "systemctl set-default ${cluster_id}-${default_target}.target",
    unless  => "test `/bin/systemctl get-default` = '${cluster_id}-${default_target}.target'",
    require => [Package['systemd'], File["/etc/systemd/system/${cluster_id}-${default_target}.target"]],
  }
}
