# @summary Schedules PostgreSQL exports for a managed Compose project.
#
# Called only for enabled backups. Uses the shared Docker tools and systemd wrappers; the host's central directory
# management removes undeclared units. The timer runs exports independently of Puppet and Compose monitoring.
#
# @example Schedule a managed project with explicit effective settings
#   docker::compose_backup { 'example':
#     backup_service    => 'db',
#     daemon_reload     => 'docker_compose_systemd_daemon_reload_example',
#     on_calendar       => '*-*-* 05:00:00',
#     project_directory => '/opt/docker/example',
#     retention_days    => 7,
#   }
#
# @param backup_service
#   Explicit Compose service name supplied by docker::compose. The runner selects its single running container.
#
# @param daemon_reload
#   Existing Compose project's daemon-reload exec, supplied by docker::compose.
#
# @param on_calendar
#   Effective local-time systemd calendar expression, supplied by docker::compose.
#
# @param project_directory
#   Existing root-owned project directory, supplied by docker::compose.
#
# @param retention_days
#   Effective positive retention in days, supplied by docker::compose.
#
# @api private
define docker::compose_backup (
  Pattern[/\A[A-Za-z0-9_.-]+\z/]                           $backup_service,
  String[1]                                                $daemon_reload,
  Pattern[/\A[^\r\n]+\z/]                                  $on_calendar,
  Pattern[/\A\/opt\/docker\/[A-Za-z0-9][A-Za-z0-9_.-]*\z/] $project_directory,
  Integer[1]                                               $retention_days,
) {
  # Enabled backups require the shared runtime and systemd integration.
  if (defined(Class['docker']) and $name =~ /\A[A-Za-z0-9][A-Za-z0-9_.-]*\z/
    and defined(Class['basic_settings::systemd'])) {
    # Use existing failure notifications; the timer wrapper inherits the configured monitoring backend.
    $unit_name = "docker-compose-${name}-backup"
    $monitoring = $docker::monitoring_enable and $basic_settings::monitoring::package != 'none'
    $failure = $monitoring ? { true => { 'OnFailure' => 'notify-failed@%i.service' }, default => {} }

    # Pass the caller's explicit service name to the shared backup runner.
    $backup_command = "/usr/local/lib/puppet/docker-compose-backup ${name} ${project_directory} ${backup_service} ${retention_days}"

    # Docker socket access is privileged; host writes stay within this project's private backup directory.
    basic_settings::systemd_service { $unit_name:
      daemon_reload => $daemon_reload,
      description   => "Docker Compose backup ${name}",
      enable        => false,
      install       => {},
      unit          => stdlib::merge($failure, { 'After' => 'docker.service' }),
      service       => {
        'ExecStart'               => $backup_command,
        'Type'                    => 'oneshot',
        'User'                    => 'root',
        'WorkingDirectory'        => $project_directory,
        'TimeoutStartSec'         => '3600',
        'TimeoutStopSec'          => '30',
        'KillMode'                => 'mixed',
        'UMask'                   => '0077',
        'NoNewPrivileges'         => 'true',
        'PrivateTmp'              => 'true',
        'PrivateDevices'          => 'true',
        'ProtectHome'             => 'true',
        'ProtectSystem'           => 'strict',
        'ReadWritePaths'          => "${project_directory}/backup",
        'ProtectKernelTunables'   => 'true',
        'ProtectKernelModules'    => 'true',
        'ProtectControlGroups'    => 'true',
        'RestrictSUIDSGID'        => 'true',
        'LockPersonality'         => 'true',
        'SystemCallArchitectures' => 'native',
      },
      require       => [Class['docker'], File["${project_directory}/backup"]],
    }

    # Only the timer is monitored: an idle oneshot service is healthy between runs.
    basic_settings::systemd_timer { $unit_name:
      daemon_reload     => $daemon_reload,
      description       => "Docker Compose backup ${name}",
      monitoring_enable => $monitoring,
      state             => running,
      timer             => { 'OnCalendar' => $on_calendar, 'Persistent' => 'true' },
      require           => Basic_settings::Systemd_service[$unit_name],
    }

    # Load changed units before activation and restart the timer when its schedule changes.
    Service <| title == "${unit_name}.timer" |> {
      require   +> Exec[$daemon_reload],
      subscribe +> File["/etc/systemd/system/${unit_name}.timer"],
    }
  } else {
    fail('docker::compose_backup requires docker, basic_settings::systemd and a valid Compose project name.')
  }
}
