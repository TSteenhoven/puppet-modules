# @summary Runs a guarded command in one running service container of a managed Compose project.
#
# Declare `docker` and the corresponding `docker::compose` stack, directly or through an application wrapper.
# This resource waits for that stack; it does not manage its files, start containers or allocate a terminal.
# Container discovery excludes one-off `docker compose run` containers and must find exactly one running service
# container.
# Missing or ambiguous matches fail without executing the command.
# Commands and guards are marked Sensitive and output logging is disabled; never put secrets in command arguments.
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
#   for shell code.
#
# @param compose_name
#   Title of the managed docker::compose resource and value of its Compose project label.
#
# @param service
#   Compose service label identifying the container; exactly one running container must match.
#
# @param creates
#   Optional absolute host path checked by Puppet; an existing path skips execution. Default undef.
#
# @param environment
#   Container process environment shared by command and unless, default empty. Use Sensitive values for secrets in
#   Puppet reports.
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
# @api public
define docker::compose_exec (
  Array[String, 1]                                 $command,
  Pattern[/\A[A-Za-z0-9_.-]+\z/]                   $compose_name,
  Pattern[/\A[A-Za-z0-9_.-]+\z/]                   $service,
  Optional[Pattern[/\A\/[^\r\n]+\z/]]              $creates      = undef,
  Hash[String, Variant[String, Sensitive[String]]] $environment  = {},
  Optional[Pattern[/\A\/[^\r\n]+\z/]]              $stdin_file   = undef,
  Integer[1]                                       $timeout      = 120,
  Optional[Array[String, 1]]                       $unless       = undef,
) {
  # Validate environment keys before forming Docker options; values are escaped independently below.
  if (defined(Class['docker']) and $environment.keys.all |$key| { $key =~ /\A[A-Za-z_][A-Za-z0-9_]*\z/ }) {
    # Share container discovery with scheduled backups, including exclusion of temporary compose run containers.
    $compose_name_shell = stdlib::shell_escape($compose_name)
    $service_shell = stdlib::shell_escape($service)
    $container_lookup_command = join([
      'container_id=$(/usr/local/lib/puppet/docker-compose-container',
      "${compose_name_shell} ${service_shell}) || exit 1",
    ], ' ')

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
    $command_args_shell = $command.map |$argument| { stdlib::shell_escape($argument) }
    $docker_exec_command = join(concat(['/usr/bin/docker exec'], $environment_args_shell), ' ')

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

    # Apply the same discovery and execution boundary to the read-only application guard.
    if ($unless != undef) {
      # Shell escaping is identical for the guard and the mutation.
      $unless_args_shell = $unless.map |$argument| { stdlib::shell_escape($argument) }
      $unless_command = Sensitive.new(join([
        $container_lookup_command,
        join(concat([$docker_exec_command, '"$container_id"'], $unless_args_shell, ['< /dev/null']), ' '),
      ], "\n"))
    } else {
      # An omitted guard performs no Docker calls during noop; creates stays a local Puppet check.
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
      provider  => shell,
      require   => [Docker::Compose[$compose_name], File['/usr/local/lib/puppet/docker-compose-container']],
      timeout   => $timeout,
      unless    => $unless_command,
    }
  } else {
    fail('docker::compose_exec requires the docker class and valid shell variable names for environment keys.')
  }
}
