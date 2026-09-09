# @summary Registers monitoring for a Docker Compose project.
#
# lint:ignore:140chars
# This helper builds the command line for the shared `check_compose` plugin and registers it through `basic_settings::monitoring_custom`. It is normally called by `docker::compose`, but can be used directly for externally managed Compose projects that still need the repository's monitoring behavior.
# lint:endignore
#
# @example Monitor an existing Compose project
#   docker::compose_monitoring { 'example':
#     project_directory => '/opt/docker/example',
#     compose_files     => ['/opt/docker/example/docker-compose.yml'],
#   }
#
# @param project_directory
#   Absolute Compose project directory passed to the monitoring plugin.
#
# @param compose_files
#   Compose file paths passed to the monitoring plugin.
#
# @param detail_limit
#   Maximum number of diagnostic characters emitted before the `Interpretation:` section.
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
#   Treats orphaned Compose containers as critical when `true`.
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
#   Grace period in seconds for containers in a starting state.
#
# @param timeout
#   Monitoring timeout in seconds.
#
# @api public
define docker::compose_monitoring (
  Pattern[/\A\/[A-Za-z0-9._\/-]+\z/]       $project_directory,
  Array[String]                            $compose_files     = [],
  Integer                                  $detail_limit      = 6000,
  Enum['present', 'absent']                $ensure            = present,
  Optional[String]                         $env_file          = undef,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]    $expected_exited   = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]    $health_required   = [],
  Integer                                  $interval          = 300,
  Boolean                                  $orphan_critical   = false,
  Optional[String]                         $package           = undef,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]    $profiles          = [],
  Optional[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $project_name      = undef,
  Integer                                  $starting_grace    = 300,
  Integer                                  $timeout           = 60,
) {
  if ($name =~ /\A[a-zA-Z0-9_.-]+\z/) {
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
      default => '',
    }

    # Join the command arguments together.
    $cmd = join([
        "-d ${project_directory}",
        $project_name_arg,
        $compose_files_arg,
        $env_file_arg,
        " -n ${name} -g ${starting_grace} -l ${detail_limit}",
        $expected_exited_arg,
        $health_required_arg,
        $profiles_arg,
        $orphan_critical_arg,
    ], '')

    # The stack check parses Docker's JSON output with jq.
    if (!defined(Package['jq'])) {
      package { 'jq':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Create the monitoring resource for this stack.
    basic_settings::monitoring_custom { "docker_compose_${name}":
      ensure   => $ensure,
      source   => 'puppet:///modules/docker/check_compose',
      cmd      => $cmd,
      friendly => "Docker Compose ${name}",
      interval => $interval,
      package  => $package,
      timeout  => $timeout,
      require  => Package['jq'],
    }
  } else {
    fail('docker::compose_monitoring titles may only contain letters, numbers, dots, underscores, and hyphens.')
  }
}
