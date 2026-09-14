# @summary Deploys a GitLab Runner Compose manager with optional one-time registration.
#
# Declare `docker` and `basic_settings::systemd` first, with Docker's APT source available.
# The title is the Compose project name; private state lives in `/opt/docker/<title>/config`.
# Puppet manages the directory entry, never the contents of `config.toml` or `.runner_system_id`.
# Registration uses docker::compose_exec in the running Compose container; an existing config.toml prevents another
# registration.
# Existing configuration is not parsed or repaired; validate a failed or interrupted registration manually before
# retrying Puppet.
# Use a dedicated host or VM for trusted builds: the manager's Docker socket grants host-level access.
# New registrations use the host daemon for unprivileged job containers, `alpine:latest` and the `if-not-present` pull
# policy.
# Manager mounts and runner_ip are not inherited by job containers; existing executor configuration remains unmanaged.
# The manager bind-mounts the root-owned 0700 config directory and the host socket; the bootstrap token is outside both
# mounts.
# The Docker executor creates separate build, helper and service containers; inspect their actual volumes and
# privileges.
# Check the effective DOCKER_HOST and runners.docker.host before relying on the host-daemon configuration.
# The fixed if-not-present policy can reuse cached private images without fresh registry authorization; restrict runner
# access.
# See the dedicated Runner node in `examples/docker.pp` for host setup, registration and validation steps.
#
# @example Deploy an already registered runner without retaining a bootstrap secret
#   include docker
#   include basic_settings::systemd
#
#   # Preserve a manually prepared registration in the private project config directory.
#   docker::gitlab_runner { 'gitlab-runner':
#     require => Class['docker'],
#   }
#
# @param auto_register
#   Defaults to false. When true, run registration only while config.toml is absent; existing files require manual
#   validation.
#   The local existence guard has no registration side effects during noop, but also skips empty, damaged or partial
#   files.
#   After failure, pause Puppet runs and inspect local state and the GitLab runner manager through a protected admin
#   session.
#   A timeout can leave registration running inside the container; check the process before attempting recovery.
#   Restore config.toml and .runner_system_id together, or reconcile the GitLab registration before deliberately
#   removing state.
#   Never delete config.toml just to force a retry; keep one Puppet agent responsible and avoid concurrent manual
#   registration.
#   When false, prepare an existing registration or register manually before using the runner.
#
# @param ensure
#   Defaults to present. Absent uses Compose's directory removal; stop and detach the stack yourself before deleting
#   local state.
#   Pause the runner and drain jobs before maintenance; SIGQUIT has 240 seconds of Compose grace within a 300-second
#   systemd stop.
#   Before removal, back up required data, detach the systemd target binding, reload systemd and stop the stack with its
#   files intact.
#   Retire the systemd service and GitLab registration separately; absent does neither and does not remove Docker named
#   volumes.
#   Deleting the project directory loses its bootstrap token, runtime token, system identity and project-local
#   bind-mount data.
#
# @param image_tag
#   Runner manager and registration image tag as a String, default latest. Tag syntax and availability are checked by
#   Docker.
#   Line breaks are rejected because this value is written to a single .env entry.
#   Replacing the manager preserves its mounted registration; it does not change existing executor settings or register
#   again.
#
# @param monitoring_detail_limit
#   Compose check diagnostic character limit, default 6000; passed unchanged to `docker::compose`.
#
# @param monitoring_expected_exited
#   Container names allowed to exit, default empty; passed unchanged to `docker::compose`.
#
# @param monitoring_health_required
#   Container names requiring Docker health state, default empty; passed unchanged to `docker::compose`.
#
# @param monitoring_interval
#   Compose monitoring interval in seconds, default 300.
#
# @param monitoring_orphan_critical
#   Treat orphan containers as critical, default false.
#
# @param monitoring_profiles
#   Compose profiles for monitoring, default empty.
#
# @param monitoring_starting_grace
#   Compose startup grace period in seconds, default 300.
#
# @param monitoring_timeout
#   Compose monitoring timeout in seconds, default 60.
#
# @param runner_description
#   Local runner name used at registration and by validation, default docker-runner; no control characters.
#
# @param runner_ip
#   Optional IPv4 or IPv6 address without a subnet, default undef. Undef or an empty string retains normal DNS
#   resolution.
#   Compose maps the hostname parsed from runner_url with Puppet's native URI type, including registration inside the
#   manager.
#   Does not change the URL, TLS verification or Docker executor job containers.
#   Requires Compose 2.24.1 or later for the HOST:IP form; omit subnet prefixes and IPv6 brackets.
#   If GitLab is reachable only through this mapping, helper checkout and artifact upload can fail after registration
#   succeeds.
#   Provide DNS reachable from each container network, or merge extra_hosts into the existing runner's runners.docker
#   table.
#   For example: extra_hosts = ["gitlab.example.org:192.0.2.50"]. Preserve other entries, runtime tokens and system
#   identity.
#   Apply that executor setting after first registration or while an existing runner is paused with jobs drained.
#   Puppet does not reconcile it when runner_ip changes; review manager, helper and job DNS/TLS plus host-daemon
#   registry access.
#   Removing the mapping restores normal manager DNS; mapping changes refresh the manager, so pause and drain jobs
#   first.
#
# @param runner_token
#   Optional Sensitive runner authentication token, default undef; only required on the host for a new automatic
#   registration.
#   Undef removes the bootstrap file without changing the runtime token; remove the profile's mandatory lookup too.
#   Use an authentication token from a runner created in GitLab, not a legacy registration token; set access and tags in
#   GitLab.
#   The private bootstrap file is fed through stdin to CI_SERVER_TOKEN; no terminal is allocated and registration output
#   is discarded.
#   Sensitive protects normal output but does not encrypt every catalog/cache or hide secrets from host and Docker
#   administrators.
#
# @param runner_url
#   GitLab instance HTTPS URL, default https://gitlab.com/; credentials, query strings and fragments are rejected.
#   Existing registration URLs are not rewritten; keep this value consistent with the active config.toml.
#
# @param target
#   Existing systemd target suffix for this Compose stack, default services; passed unchanged to `docker::compose`.
#
# @api public
define docker::gitlab_runner (
  Boolean                               $auto_register              = false,
  Enum['present', 'absent']             $ensure                     = present,
  String                                $image_tag                  = 'latest',
  Integer                               $monitoring_detail_limit    = 6000,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_expected_exited = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_health_required = [],
  Integer                               $monitoring_interval        = 300,
  Boolean                               $monitoring_orphan_critical = false,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_profiles        = [],
  Integer                               $monitoring_starting_grace  = 300,
  Integer                               $monitoring_timeout         = 60,
  String                                $runner_description         = 'docker-runner',
  Optional[String]                      $runner_ip                  = undef,
  Optional[Sensitive[String]]           $runner_token               = undef,
  String                                $runner_url                 = 'https://gitlab.com/',
  String                                $target                     = 'services',
) {
  # Restrict project names to the Compose grammar before deriving paths and unit identities.
  if ($name =~ /\A[a-z0-9][a-z0-9_-]*\z/) {
    # Removal must remain possible without the Docker or systemd parent classes.
    if ($ensure == present) {
      # Registration runs inside the container started by the existing Docker/systemd integration.
      if (defined(Class['docker']) and defined(Class['basic_settings::systemd'])) {
        # Restrict input before native parsing so URI errors cannot disclose credentials or accept unsafe .env content.
        $runner_uri = if ($runner_url =~ /\A(?i:https):\/\/[A-Za-z0-9.-]+(?::[0-9]*)?(?:\/[A-Za-z0-9._~\/-]*)?\z/) {
          URI($runner_url)
        } else {
          undef
        }
        $runner_url_error = if ($runner_uri != undef
          and $runner_uri.host =~ /\A(?i:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*\.?)\z/
          and $runner_uri.port =~ Integer[1, 65535]) {
          undef
        } else {
          'docker::gitlab_runner runner_url must be a credential-free HTTPS URL with a hostname and valid port, without query strings or fragments.' # lint:ignore:140chars
        }

        # Reject invalid addresses before creating the stack, while accepting an omitted or empty override.
        $runner_ip_correct = $runner_ip ? {
          ''      => undef,
          default => $runner_ip,
        }
        $runner_ip_error = $runner_ip_correct ? {
          undef                       => undef,
          Stdlib::IP::Address::Nosubnet => undef,
          default                     => 'docker::gitlab_runner runner_ip must be a valid IPv4 or IPv6 address without a subnet.',
        }
        if ($runner_url_error == undef and $runner_ip_error == undef
          and $runner_description =~ /\A[^[:cntrl:]]+\z/ and $runner_description !~ /\A\s|\s\z/
          and $image_tag !~ /[\r\n]/) {
          # Extract only the parsed host for Compose; registration keeps the original URL, including its port and path.
          $runner_host = $runner_uri.host

          # Keep bootstrap material outside the config directory mounted by the manager.
          $project_directory = "/opt/docker/${name}"
          $token_file = "${project_directory}/runner-token"

          # Delegate files, lifecycle, targets and monitoring to the existing Compose implementation.
          docker::compose { $name:
            ensure                     => $ensure,
            compose_content            => template('docker/gitlab_runner.yaml'),
            env_content                => template('docker/gitlab_runner.env'),
            monitoring_detail_limit    => $monitoring_detail_limit,
            monitoring_expected_exited => $monitoring_expected_exited,
            monitoring_health_required => $monitoring_health_required,
            monitoring_interval        => $monitoring_interval,
            monitoring_orphan_critical => $monitoring_orphan_critical,
            monitoring_profiles        => $monitoring_profiles,
            monitoring_starting_grace  => $monitoring_starting_grace,
            monitoring_timeout         => $monitoring_timeout,
            project_directories        => { 'config' => { 'owner' => 'root', 'group' => 'root', 'mode' => '0700' } },
            target                     => $target,
          }

          # Retain bootstrap content only while explicitly supplied for automatic registration.
          if ($auto_register and $runner_token != undef) {
            # Preserve the Sensitive value all the way to the private File resource.
            $token_ensure = file
            $token_content = $runner_token
          } else {
            # Removing this bootstrap copy never touches the rotating token in config.toml.
            $token_ensure = absent
            $token_content = undef
          }

          # Never expose bootstrap values in file diffs or filebucket backups.
          # This file is raw authentication material; a comment header would become part of the token.
          file { $token_file:
            ensure    => $token_ensure,
            content   => $token_content,
            owner     => 'root',
            group     => 'root',
            mode      => '0600',
            backup    => false,
            show_diff => false,
            require   => File["docker_compose_${name}_project_directory"],
          }

          # Puppet's creates guard reads only local file existence, including during --noop.
          if ($auto_register) {
            # Read the token from stdin inside the container, keeping it out of Docker arguments and its stored environment.
            $token_reader = join([
              'set -eu; umask 077; exec >/dev/null 2>&1;',
              'CI_SERVER_TOKEN=$(cat); export CI_SERVER_TOKEN;',
              'exec gitlab-runner register "$@"',
            ], ' ')

            # Reuse Compose container selection and argument escaping while retaining the private token input.
            docker::compose_exec { "docker_gitlab_runner_register_${name}":
              command      => [
                '/bin/sh', '-c', $token_reader, 'register',
                '--non-interactive', '--url', $runner_url, '--executor', 'docker',
                '--docker-image', 'alpine:latest', '--docker-pull-policy', 'if-not-present',
                '--description', $runner_description,
              ],
              compose_name => $name,
              service      => 'runner',
              creates      => "${project_directory}/config/config.toml",
              stdin_file   => $token_file,
              timeout      => 300,
              require      => File[$token_file],
            }
          }
        } else {
          fail(pick($runner_url_error, $runner_ip_error, 'docker::gitlab_runner requires a printable runner_description and an image_tag without line breaks.')) # lint:ignore:140chars
        }
      } else {
        fail('docker::gitlab_runner requires the docker and basic_settings::systemd classes before deploying a runner.')
      }
    } else {
      docker::compose { $name:
        ensure => absent,
        target => $target,
      }
    }
  } else {
    fail('docker::gitlab_runner titles must start with a lowercase letter or digit and contain only lowercase letters, digits, underscores and hyphens.') # lint:ignore:140chars
  }
}
