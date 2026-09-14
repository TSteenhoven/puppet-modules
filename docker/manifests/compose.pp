# @summary Deploys and monitors one Docker Compose project as a systemd service.
#
# This defined type creates a root-only project directory under `/opt/docker`, manages optional `.env` content and
# project-local directories, validates rendered Compose content or a file from an HTTPS, local file, or Puppet
# file-server source, and creates a `docker-compose-<title>.service` when the shared systemd wrapper is available.
# It also registers a stack-level monitoring check so container health can be evaluated separately from the
# orchestration unit.
# Declare `docker` before deploying a present stack; removal of a project directory does not require that class.
#
# @example Deploy a Compose stack from a Puppet file source
#   docker::compose { 'example':
#     compose_source => 'puppet:///modules/profile/example/docker-compose.yml',
#   }
#
# @example Deploy a stack with sensitive environment content
#   docker::compose { 'example':
#     compose_source => 'file:///srv/puppet/example/docker-compose.yml',
#     env_content    => Sensitive("COMPOSE_PROJECT_NAME=example\n"),
#   }
#
# @param compose_checksum
#   Optional SHA256 checksum for compose_source, unavailable with compose_content. This is most useful for HTTPS sources
#   where unexpected upstream changes should fail the Puppet run.
#
# @param compose_content
#   Optional rendered Compose content, default undef. Supply exactly one of compose_content and compose_source for a
#   present stack.
#
# @param compose_source
#   Optional Compose file source, default undef. Must start with `https://`, `file:///`, or `puppet:///`; excludes
#   compose_content.
#
# @param ensure
#   Defaults to present. Absent removes only the project directory, including project-local bind-mount data.
#   It does not stop containers or remove systemd units and target bindings. Docker named volumes are not removed.
#   Back up required data, detach the target binding, reload systemd and stop the stack before removal; retire its
#   service separately.
#
# @param env_content
#   Optional `.env` file content. Strings are wrapped in `Sensitive`; explicit `Sensitive[String]` values are passed
#   through.
#
# @param env_source
#   Optional Puppet-compatible source for the `.env` file. When set, it takes precedence over `env_content` and must
#   start with `https://`, `file:///`, or `puppet:///`.
#
# @param monitoring_detail_limit
#   Optional diagnostic character limit. `undef` omits -l and uses the environment value or script default.
#
# @param monitoring_expected_exited
#   Container names that are allowed to be exited without making the stack critical, such as one-shot migration
#   containers.
#
# @param monitoring_health_required
#   Container names that must have a healthy Docker health state.
#
# @param monitoring_interval
#   Monitoring interval in seconds for the Compose stack check.
#
# @param monitoring_orphan_critical
#   Optional orphan severity. True passes -O, false passes -o; undef uses the environment value or script default.
#
# @param monitoring_profiles
#   Compose profiles passed to the monitoring check.
#
# @param monitoring_starting_grace
#   Optional startup grace in seconds. `undef` omits -g and uses the environment value or script default.
#
# @param monitoring_timeout
#   Timeout in seconds for the Compose stack monitoring check.
#
# @param project_directories
#   Optional single-segment directories created below the Compose project directory before the systemd service starts.
#   Values may override owner, group, and mode. Only the directory entry is managed; contents remain unmanaged.
#
# @param target
#   `basic_settings::systemd` target suffix that should bind to the generated Compose service. The default is
#   `services`.
#
# @api public
define docker::compose (
  Optional[Pattern[/\A[0-9a-fA-F]{64}\z/]]     $compose_checksum           = undef,
  Optional[String]                             $compose_content            = undef,
  Optional[String]                             $compose_source             = undef,
  Enum['present', 'absent']                    $ensure                     = present,
  Optional[Variant[String, Sensitive[String]]] $env_content                = undef,
  Optional[String]                             $env_source                 = undef,
  Optional[Integer[1]]                         $monitoring_detail_limit    = undef,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]        $monitoring_expected_exited = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]        $monitoring_health_required = [],
  Integer                                      $monitoring_interval        = 300,
  Optional[Boolean]                            $monitoring_orphan_critical = undef,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]        $monitoring_profiles        = [],
  Optional[Integer[0]]                         $monitoring_starting_grace  = undef,
  Integer                                      $monitoring_timeout         = 60,
  Hash[Pattern[/\A[A-Za-z0-9_.-]+\z/], Struct[{
        Optional[owner] => String[1],
        Optional[group] => String[1],
        Optional[mode]  => Pattern[/\A[0-7]{4}\z/],
  }]]                                          $project_directories        = {},
  String                                       $target                     = 'services',
) {
  # Validate the compose name to avoid issues with file paths and systemd unit names.
  if ($name =~ /\A[a-zA-Z0-9_.-]+\z/) {
    # Keep the Compose and environment files inside this project's directory.
    $project_directory = "/opt/docker/${name}"
    $compose_file = "${project_directory}/docker-compose.yml"
    $env_file = "${project_directory}/.env"

    # Give callers stable resource aliases and service names for this project.
    $project_directory_alias = "docker_compose_${name}_project_directory"
    $compose_file_alias = "docker_compose_${name}_compose_file"
    $env_file_alias = "docker_compose_${name}_env_file"
    $service_name = "docker-compose-${name}"
    $daemon_reload = "docker_compose_systemd_daemon_reload_${name}"

    # Check if ensure is present to determine if the compose stack should be deployed or removed.
    if ($ensure == present) {
      # Deployment consumes Docker's package resources; cleanup below can run without the parent class.
      if (($compose_source != undef or $compose_content != undef) and defined(Class['docker'])) {
        # Accept either rendered content or a trusted source; downloaded checksums apply only to sources.
        if (($compose_source == undef and $compose_content != undef and $compose_checksum == undef)
          or ($compose_content == undef and $compose_source =~ /(?i:\A(?:https:\/\/|file:\/\/\/|puppet:\/\/\/))/)) {
          # Validate an optional environment source before creating any part of the Compose project.
          if ($env_source == undef or $env_source =~ /(?i:\A(?:https:\/\/|file:\/\/\/|puppet:\/\/\/))/) {
            # Determine the content of the environment file based on the provided parameters.
            if ($env_source == undef) {
              case $env_content {
                String: {
                  # Wrap plain environment content to keep it out of ordinary Puppet reports.
                  $env_file_content = Sensitive.new($env_content)
                }
                default: {
                  # Preserve environment content that is already marked Sensitive.
                  $env_file_content = $env_content
                }
              }
            } else {
              # Use the validated external environment source without inline file content.
              $env_file_content = undef
            }

            # Normalize the compose checksum to lowercase if provided, otherwise leave it as undef.
            $compose_checksum_value = $compose_checksum ? {
              undef   => undef,
              default => $compose_checksum.downcase(),
            }

            # lint:ignore:140chars
            # Check if monitoring is enabled to determine if the compose service should be configured with failure monitoring for integration with the monitoring stack.
            # lint:endignore
            $monitoring_enable = defined(Class['basic_settings::monitoring'])
            if ($monitoring_enable) {
              # Inherit the monitoring backend and attach its unit-failure notification hook.
              $monitoring_package = $basic_settings::monitoring::package
              $unit_failure = {
                'OnFailure' => 'notify-failed@%i.service',
              }
            } else {
              # Disable monitoring registration and failure hooks without a monitoring class.
              $monitoring_package = 'none'
              $unit_failure = {}
            }

            # Check if docker-compose-plugin package is not defined
            if (!defined(Package['docker-compose-plugin'])) {
              package { 'docker-compose-plugin':
                ensure          => installed,
                install_options => ['--no-install-recommends', '--no-install-suggests'],
                require         => Package['docker'],
              }
            }

            # Check if docker directory is not defined
            if (!defined(File['/opt/docker'])) {
              file { '/opt/docker':
                ensure => directory,
                owner  => 'root',
                group  => 'root',
                mode   => '0700',
              }
            }

            # Create a directory for docker-compose
            file { $project_directory:
              ensure => directory,
              alias  => $project_directory_alias,
              path   => $project_directory,
              owner  => 'root',
              group  => 'root',
              mode   => '0700',
            }

            # Create requested bind-mount source directories while leaving their contents unmanaged.
            $project_directory_resources = $project_directories.map |$directory_name, $directory_settings| {
              # Resolve each managed subdirectory beneath the Compose project directory.
              $managed_directory = "${project_directory}/${directory_name}"
              file { $managed_directory:
                ensure  => directory,
                owner   => pick($directory_settings['owner'], 'root'),
                group   => pick($directory_settings['group'], 'root'),
                mode    => pick($directory_settings['mode'], '0700'),
                require => File[$project_directory],
              }
              File[$managed_directory]
            }

            # Manage the environment file for the compose stack if either a source or content is provided.
            if ($env_source != undef or $env_content != undef) {
              file { $env_file:
                ensure  => file,
                path    => $env_file,
                alias   => $env_file_alias,
                source  => $env_source,
                content => $env_file_content,
                owner   => 'root',
                group   => 'root',
                mode    => '0600',
                require => File[$project_directory],
              }
              $compose_env_command = " --env-file ${env_file}"
              $compose_require = File[$env_file]
              $env_monitoring = $env_file
            } else {
              # Run Compose without an environment-file argument or environment-file monitoring dependency.
              $compose_env_command = ''
              $compose_require = File[$project_directory]
              $env_monitoring = undef
            }

            # Keep Compose commands local; other defined types consume the managed File aliases above.
            $compose_config_command = "/usr/bin/docker compose --project-directory ${project_directory}${compose_env_command} --file % config --quiet" # lint:ignore:140chars
            $compose_up_command = "/usr/bin/docker compose --project-name ${name} --project-directory ${project_directory}${compose_env_command} --file ${compose_file} up --detach --remove-orphans" # lint:ignore:140chars
            $compose_down_command = "/usr/bin/docker compose --project-name ${name} --project-directory ${project_directory}${compose_env_command} --file ${compose_file} down --remove-orphans" # lint:ignore:140chars

            # Validate sourced or rendered Compose content before it is promoted into the project directory.
            file { $compose_file:
              ensure         => file,
              path           => $compose_file,
              alias          => $compose_file_alias,
              content        => $compose_content,
              source         => $compose_source,
              checksum       => 'sha256',
              checksum_value => $compose_checksum_value,
              validate_cmd   => $compose_config_command,
              owner          => 'root',
              group          => 'root',
              mode           => '0600',
              require        => [$compose_require, Package['docker-compose-plugin']],
            }

            # Create the Compose unit only when the shared systemd class is available.
            if (defined(Class['basic_settings::systemd'])) {
              # Determine the service subscription based
              if ($env_source != undef or $env_content != undef) {
                # Start and refresh the stack only after both Compose and environment files are managed.
                $service_require_base = [Package['docker', 'docker-compose-plugin'], File[$env_file, $compose_file]]
                $service_subscribe = File[$env_file, $compose_file]
              } else {
                # Start and refresh the stack using only the Compose file when no environment file is configured.
                $service_require_base = [Package['docker', 'docker-compose-plugin'], File[$compose_file]]
                $service_subscribe = File[$compose_file]
              }
              $service_require = concat($service_require_base, $project_directory_resources)

              # Reload systemd after the generated compose service unit changes.
              exec { $daemon_reload:
                command     => '/usr/bin/systemctl daemon-reload',
                refreshonly => true,
                require     => Package['systemd'],
              }

              # Manage the compose stack as a root-run orchestration service for the Docker daemon.
              basic_settings::systemd_service { $service_name:
                description        => "Docker Compose stack ${name}",
                monitoring_enable  => $monitoring_enable,
                monitoring_package => $monitoring_package,
                service_subscribe  => $service_subscribe,
                service            => {
                  'ExecStart'               => $compose_up_command,
                  'ExecStop'                => $compose_down_command,
                  'LockPersonality'         => 'true',
                  'MemoryDenyWriteExecute'  => 'true',
                  'NoNewPrivileges'         => 'true',
                  'PrivateDevices'          => 'true',
                  'PrivateTmp'              => 'true',
                  'ProtectClock'            => 'true',
                  'ProtectHostname'         => 'true',
                  'ProtectControlGroups'    => 'true',
                  'ProtectKernelLogs'       => 'true',
                  'ProtectKernelModules'    => 'true',
                  'ProtectKernelTunables'   => 'true',
                  'ProtectSystem'           => 'full',
                  'RemainAfterExit'         => 'yes',
                  'RestrictSUIDSGID'        => 'true',
                  'SystemCallArchitectures' => 'native',
                  'TimeoutStartSec'         => '300',
                  'TimeoutStopSec'          => '300',
                  'Type'                    => 'oneshot',
                  'UMask'                   => '0077',
                  'User'                    => 'root',
                  'WorkingDirectory'        => $project_directory,
                },
                unit               => stdlib::merge($unit_failure, {
                    'After'    => ['docker.service', 'network-online.target'],
                    'Requires' => 'docker.service',
                    'Wants'    => 'network-online.target',
                }),
                daemon_reload      => $daemon_reload,
                enable             => false,
                require            => $service_require,
              }

              # lint:ignore:140chars
              # If the target is not 'services', create a dependency on the specified target to allow for flexible ordering of the compose stack in relation to other systemd services and targets.
              # lint:endignore
              basic_settings::systemd_drop_in { "${service_name}_dependency":
                target_unit   => "${basic_settings::systemd::cluster_id}-${target}.target",
                unit          => {
                  'BindsTo' => "${service_name}.service",
                },
                daemon_reload => $daemon_reload,
                require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-${target}"],
              }

              # The shared service wrapper manages enablement only; Compose must also start on its first Puppet run.
              # Wait for both the unit and target binding to be loaded before starting or refreshing the stack.
              Service <| title == $service_name |> {
                ensure  => running,
                require +> Exec[$daemon_reload],
              }
            }

            # Monitor the rendered Compose stack separately from the orchestration service unit.
            docker::compose_monitoring { $name:
              project_directory => $project_directory,
              compose_files     => [$compose_file],
              detail_limit      => $monitoring_detail_limit,
              env_file          => $env_monitoring,
              expected_exited   => $monitoring_expected_exited,
              health_required   => $monitoring_health_required,
              interval          => $monitoring_interval,
              orphan_critical   => $monitoring_orphan_critical,
              package           => $monitoring_package,
              profiles          => $monitoring_profiles,
              project_name      => $name,
              starting_grace    => $monitoring_starting_grace,
              timeout           => $monitoring_timeout,
              require           => File[$compose_file],
            }
          } else {
            fail('docker::compose env_source must start with https://, file:///, or puppet:///')
          }
        } else {
          fail('docker::compose requires either compose_content without a checksum, or compose_source starting with https://, file:///, or puppet:///') # lint:ignore:140chars
        }
      } else {
        fail('docker::compose requires the docker class and compose_source or compose_content when ensure is present.')
      }
    } else {
      # Remove the directory for docker-compose
      file { $project_directory:
        ensure => absent,
        force  => true,
      }
    }
  } else {
    fail('docker::compose titles may only contain letters, numbers, dots, underscores, and hyphens.')
  }
}
