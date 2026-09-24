# @summary Runs a guarded command in a container belonging to a managed Compose deployment.
#
# Declare `docker` and the corresponding `docker::compose` stack, directly or through an application wrapper.
# This resource waits for that stack; it does not manage its files, start containers or allocate a terminal.
# Service discovery excludes one-off docker compose run containers and requires exactly one running match.
# For an application-managed sibling without Compose service labels, select its exact container_name instead.
# Docker exec fails for a missing or stopped container. Explicit container names are not checked against project
# labels; the caller must supply the name belonging to this deployment. Specify exactly one selection method.
# Commands and guards are marked Sensitive and output logging is disabled. Sensitive arguments are redacted in reports,
# but remain visible to anyone permitted to inspect host or container process arguments.
# Environment values are passed through Docker's command arguments and are visible to host/Docker administrators.
# For secrets that must stay out of arguments, use a protected stdin_file and read it inside the container.
#
# @example Initialize application data only when the container reports it is missing
#   docker::compose_exec { 'initialize-example':
#     command      => ['/usr/local/bin/app', 'initialize'],
#     compose_name => 'example',
#     service      => 'web',
#     unless       => ['/usr/local/bin/app', 'initialized'],
#   }
#
# @param command
#   Executable and arguments inside the container. Each array element is escaped separately; use /bin/sh -c explicitly
#   for shell code. Sensitive arguments remain protected while the command is assembled.
#
# @param compose_name
#   Title of the managed docker::compose resource. Also the project label when selecting by service.
#
# @param container_name
#   Exact Docker container name for application-managed siblings without Compose labels. Defaults to undef;
#   mutually exclusive with service. Container names are unique within the local Docker daemon.
#
# @param creates
#   Optional absolute host path checked by Puppet; an existing path skips execution. Default undef.
#
# @param environment
#   Container process environment shared by command, onlyif and unless, default empty. Use Sensitive values for
#   secrets in Puppet reports.
#
# @param onlyif
#   Optional read-only executable and arguments inside the container, accepting Sensitive[String]. Exit 0 allows
#   command; other exit codes skip it. Also runs during Puppet --noop. Default undef adds no prerequisite check.
#
# @param service
#   Compose service label; exactly one running container must match. Defaults to undef; excludes container_name.
#
# @param stdin_file
#   Optional absolute host file read as stdin for command only, enabling docker exec -i. Manage its permissions and
#   dependency yourself.
#
# @param timeout
#   Maximum seconds for each command or guard, default 120. Timing out the Docker client may leave the container process
#   running.
#
# @param unless
#   Optional read-only executable and arguments inside the container. Exit 0 skips command; also runs during Puppet
#   --noop. Default undef.
#
# @param user
#   Optional container user or UID, optionally with a group, for command and both guards. Default undef uses the image
#   user. This does not change the host user connecting to Docker.
#
# @api public
define docker::compose_exec (
  Array[Variant[String, Sensitive[String]], 1]           $command,
  Pattern[/\A[A-Za-z0-9_.-]+\z/]                         $compose_name,
  Optional[Pattern[/\A[A-Za-z0-9][A-Za-z0-9_.-]*\z/]]    $container_name = undef,
  Optional[Pattern[/\A\/[^\r\n]+\z/]]                    $creates        = undef,
  Hash[String, Variant[String, Sensitive[String]]]       $environment    = {},
  Optional[Array[Variant[String, Sensitive[String]], 1]] $onlyif         = undef,
  Optional[Pattern[/\A[A-Za-z0-9_.-]+\z/]]               $service        = undef,
  Optional[Pattern[/\A\/[^\r\n]+\z/]]                    $stdin_file     = undef,
  Integer[1]                                             $timeout        = 120,
  Optional[Array[Variant[String, Sensitive[String]], 1]] $unless         = undef,
  Optional[String[1]]                                    $user           = undef,
) {
  # Validate the exclusive container selection and environment keys before forming Docker options.
  $selection_valid = (($service != undef and $container_name == undef) or ($service == undef and $container_name != undef))
  if (defined(Class['docker']) and $selection_valid and $environment.keys.all |$key| { $key =~ /\A[A-Za-z_][A-Za-z0-9_]*\z/ }) {
    # Use Compose labels for ordinary services and the exact Docker name for application-managed siblings.
    if ($container_name == undef) {
      # Share service discovery with scheduled backups, excluding temporary compose run containers.
      $compose_name_shell = stdlib::shell_escape($compose_name)
      $service_shell = stdlib::shell_escape($service)
      $container_lookup_command = join([
        'container_id=$(/usr/local/lib/puppet/docker-compose-container',
        "${compose_name_shell} ${service_shell}) || exit 1",
      ], ' ')
    } else {
      # Docker exec resolves this exact daemon-unique name and rejects absent or stopped containers.
      $container_name_shell = stdlib::shell_escape($container_name)
      $container_lookup_command = "container_id=${container_name_shell}"
    }

    # Preserve argument boundaries, including quotes, whitespace and shell metacharacters.
    $environment_args_shell = $environment.map |$key, $value| {
      # Unwrap only while building the Sensitive command and guard resources.
      $value_correct = $value ? {
        Sensitive => $value.unwrap,
        default   => $value,
      }
      $entry_shell = stdlib::shell_escape("${key}=${value_correct}")
      "--env ${entry_shell}"
    }
    $command_args_shell = $command.map |$argument| {
      # Unwrap only while assembling the Sensitive exec command.
      $argument_correct = $argument ? {
        Sensitive => $argument.unwrap,
        default   => $argument,
      }
      stdlib::shell_escape($argument_correct)
    }

    # Apply an explicit identity only when requested, preserving the image user for existing callers.
    if ($user != undef) {
      # Keep the container identity separate from Docker's option syntax.
      $user_shell = stdlib::shell_escape($user)
      $user_arg_shell = "--user ${user_shell}"
    } else {
      # An omitted identity leaves Docker's default intact.
      $user_arg_shell = ''
    }
    $docker_exec_command = join(concat(['/usr/bin/docker exec', $user_arg_shell], $environment_args_shell), ' ')

    # Feed a host file only to the mutation; guards must remain independent of bootstrap stdin.
    if ($stdin_file != undef) {
      # Opening the file in the host shell keeps its content out of Docker's arguments and stored environment.
      $interactive_arg = '-i'
      $stdin_file_shell = stdlib::shell_escape($stdin_file)
      $stdin_redirect = "< ${stdin_file_shell}"
    } else {
      # Close stdin for ordinary unattended commands.
      $stdin_redirect = '< /dev/null'
      $interactive_arg = ''
    }

    # Apply the same discovery and execution boundary to the read-only prerequisite guard.
    if ($onlyif != undef) {
      # Shell escaping is identical for the guard and the mutation.
      $onlyif_args_shell = $onlyif.map |$argument| {
        # Unwrap only while assembling the Sensitive exec guard.
        $argument_correct = $argument ? {
          Sensitive => $argument.unwrap,
          default   => $argument,
        }
        stdlib::shell_escape($argument_correct)
      }
      $onlyif_command = Sensitive.new(join([
        $container_lookup_command,
        join(concat([$docker_exec_command, '"$container_id"'], $onlyif_args_shell, ['< /dev/null']), ' '),
      ], "\n"))
    } else {
      # An omitted prerequisite guard adds no Docker call or execution restriction.
      $onlyif_command = undef
    }

    # Apply the same discovery and execution boundary to the read-only application guard.
    if ($unless != undef) {
      # Shell escaping is identical for the guard and the mutation.
      $unless_args_shell = $unless.map |$argument| {
        # Unwrap only while assembling the Sensitive exec guard.
        $argument_correct = $argument ? {
          Sensitive => $argument.unwrap,
          default   => $argument,
        }
        stdlib::shell_escape($argument_correct)
      }
      $unless_command = Sensitive.new(join([
        $container_lookup_command,
        join(concat([$docker_exec_command, '"$container_id"'], $unless_args_shell, ['< /dev/null']), ' '),
      ], "\n"))
    } else {
      # An omitted application guard adds no Docker call; creates stays a local Puppet check.
      $unless_command = undef
    }

    # Keep the resource title stable for callers and inherit their require/notify relationships through containment.
    exec { $name:
      command   => Sensitive.new(join([
        $container_lookup_command,
        join(concat([$docker_exec_command, $interactive_arg, '"$container_id"'], $command_args_shell, [$stdin_redirect]), ' '),
      ], "\n")),
      creates   => $creates,
      logoutput => false,
      onlyif    => $onlyif_command,
      provider  => shell,
      require   => [Docker::Compose[$compose_name], File['/usr/local/lib/puppet/docker-compose-container']],
      timeout   => $timeout,
      unless    => $unless_command,
    }
  } else {
    fail('docker::compose_exec requires docker, exactly one of service or container_name, and valid environment keys.')
  }
}
