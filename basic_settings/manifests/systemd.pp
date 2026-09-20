# @summary Installs systemd and creates the repository target ladder.
#
# This class installs systemd and related packages, removes cron/anacron in favor of systemd timers, creates the ordered
# target ladder used by service modules, and sets the host default target. The target ladder provides predictable
# ordering for system, storage, services, production, helper, and required-service workloads.
#
# @example Create the default target ladder
#   include basic_settings::systemd
#
# @param cluster_id
#   Prefix for generated target unit names, such as `core-services.target`.
#
# @param default_target
#   Target suffix selected as the system default. The default is `helpers`.
#
# @param install_options
#   Additional APT options; an empty array adds no caller options. Mandatory no-recommends and no-suggests flags are
#   appended without deduplication so they remain effective.
#
# @api public
class basic_settings::systemd (
  String $cluster_id      = 'core',
  String $default_target  = 'helpers',
  Array  $install_options = [],
) {
  # The default-target guard uses an external test and a command substitution.
  $packages = ['coreutils', 'dash']

  ensure_packages($packages, {
    'ensure'          => 'installed',
    'install_options' => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
  })

  # Include the additional package prerequisites for these resources.
  $required_packages = concat(
    $packages,
    ['systemd'],
  )

  # Install packages
  # Keep policy flags last even when caller options contain duplicate or conflicting flags.
  package { ['dbus', 'dbus-user-session', 'systemd', 'systemd-cron', 'systemd-sysv', 'libpam-systemd']:
    ensure          => installed,
    install_options => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
  }

  # Remove unnecessary packages
  package { ['anacron', 'cron']:
    ensure  => purged,
    require => Package['systemd-cron'],
  }

  # Reload systemd daemon
  exec { 'systemd_daemon_reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    require     => Package['systemd'],
  }

  # Systemd system target
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
  # Escape the target unit before using it in systemctl commands and guards.
  $default_target_unit_shell = stdlib::shell_escape("${cluster_id}-${default_target}.target")
  exec { 'set_default_target':
    command => "/bin/systemctl set-default ${default_target_unit_shell}",
    unless  => "/usr/bin/test \"\$(/bin/systemctl get-default)\" = ${default_target_unit_shell}",
    require => [Package[$required_packages], File["/etc/systemd/system/${cluster_id}-${default_target}.target"]],
  }
}
