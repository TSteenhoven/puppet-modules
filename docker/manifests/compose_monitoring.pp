# @summary Registers monitoring for a Docker Compose project.
#
# This helper builds the command line for the shared `check_compose` plugin and registers it through
# `basic_settings::monitoring_custom`. It is normally called by `docker::compose`, but can be used directly for
# externally managed Compose projects after declaring docker, which owns the shared executable and dependencies.
#
# @example Monitor an existing Compose project
#   include docker
#
#   docker::compose_monitoring { 'example':
#     project_directory => '/opt/docker/example',
#     compose_files     => ['/opt/docker/example/docker-compose.yml'],
#   }
#
# @param project_directory
#   Absolute Compose project directory passed to the monitoring plugin.
#
# @param backup_database_retention_days
#   Effective backup retention. Required alongside backup_database_type; no independent default is introduced here.
#
# @param backup_database_type
#   Optional PostgreSQL backup check. Undef omits the database check; active projects supply their effective type.
#
# @param compose_files
#   Compose file paths passed to the monitoring plugin.
#
# @param detail_limit
#   Optional diagnostic character limit. `undef` omits -l and uses the environment value or script default.
#
# @param ensure
#   Controls whether the monitoring check is present or absent.
#
# @param env_file
#   Optional `.env` file path passed to the monitoring plugin.
#
# @param expected_exited
#   Container names that are allowed to be exited.
#
# @param health_required
#   Container names that must report a healthy Docker health state.
#
# @param interval
#   Monitoring interval in seconds.
#
# @param orphan_critical
#   Optional orphan severity. True passes -O, false passes -o; undef uses the environment value or script default.
#
# @param package
#   Monitoring package override passed to `basic_settings::monitoring_custom`.
#
# @param profiles
#   Compose profiles passed to the monitoring plugin.
#
# @param project_name
#   Optional Compose project name. `undef` lets Docker Compose infer it.
#
# @param starting_grace
#   Optional startup grace in seconds. `undef` omits -g and uses the environment value or script default.
#
# @param timeout
#   Monitoring timeout in seconds.
#
# @api public
define docker::compose_monitoring (
  Pattern[/\A\/[A-Za-z0-9._\/-]+\z/]       $project_directory,
  Optional[Integer[1]]                     $backup_database_retention_days = undef,
  Optional[Enum['postgresql']]             $backup_database_type           = undef,
  Array[String]                            $compose_files                  = [],
  Optional[Integer[1]]                     $detail_limit                   = undef,
  Enum['present', 'absent']                $ensure                         = present,
  Optional[String]                         $env_file                       = undef,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]    $expected_exited                = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]    $health_required                = [],
  Integer                                  $interval                       = 300,
  Optional[Boolean]                        $orphan_critical                = undef,
  Optional[String]                         $package                        = undef,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]    $profiles                       = [],
  Optional[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $project_name                   = undef,
  Optional[Integer[0]]                     $starting_grace                 = undef,
  Integer                                  $timeout                        = 60,
) {
  # Validate the stack identifier before constructing monitoring arguments and resource names.
  if (defined(Class['docker']) and $name =~ /\A[a-zA-Z0-9_.-]+\z/) {
    # Set command arguments for the stack-specific service check.
    $project_name_arg = $project_name ? {
      undef   => '',
      default => " -p ${project_name}",
    }
    $env_file_arg = $env_file ? {
      undef   => '',
      default => " -e ${env_file}",
    }
    $compose_files_arg = length($compose_files) ? {
      0       => '',
      default => " -f ${join($compose_files, ' -f ')}",
    }
    $expected_exited_arg = length($expected_exited) ? {
      0       => '',
      default => " -x ${join($expected_exited, ',')}",
    }
    $health_required_arg = length($health_required) ? {
      0       => '',
      default => " -H ${join($health_required, ',')}",
    }
    $profiles_arg = length($profiles) ? {
      0       => '',
      default => " -P ${join($profiles, ',')}",
    }
    $orphan_critical_arg = $orphan_critical ? {
      true    => ' -O',
      false   => ' -o',
      default => '',
    }

    # Omit unset runtime options so the executable resolves environment values and defaults.
    $runtime_args = {
      '-r' => $backup_database_retention_days,
      '-g' => $starting_grace,
      '-l' => $detail_limit,
    }.filter |$option, $value| { $value != undef }.map |$option, $value| {
      # Quote each explicit runtime value as one shell argument.
      $value_shell = stdlib::shell_escape(String($value))
      " ${option} ${value_shell}"
    }

    # Database action is managed project configuration; an explicit empty option also resets executor environment values.
    $backup_type_arg = $backup_database_type ? { undef => " -b ''", default => " -b ${backup_database_type}" }

    # Join the command arguments together.
    $cmd = join([
      "-d ${project_directory}",
      $backup_type_arg,
      $project_name_arg,
      $compose_files_arg,
      $env_file_arg,
      " -n ${name}",
      join($runtime_args, ''),
      $expected_exited_arg,
      $health_required_arg,
      $profiles_arg,
      $orphan_critical_arg,
    ], '')

    # Retire the executable copies deployed by older per-stack registrations.
    file { "/etc/openitcockpit-agent/plugins/check_docker_compose_${name}":
      ensure => absent,
    }

    # Create the monitoring resource for this stack.
    basic_settings::monitoring_custom { "docker_compose_${name}":
      ensure   => $ensure,
      script   => 'docker_compose',
      cmd      => $cmd,
      friendly => "Docker Compose ${name}",
      interval => $interval,
      package  => $package,
      timeout  => $timeout,
      require  => Package['jq'],
    }
  } else {
    fail('docker::compose_monitoring requires the docker class and a title containing only letters, digits, dots, underscores and hyphens.')
  }
}
