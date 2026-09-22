# @summary Runs OCC commands and guards in Nextcloud AIO.
#
# Declare docker first and provide Docker::Compose[$compose_name], Docker::Compose_proxy[$compose_name], or
# Docker::Nextcloud[$compose_name]. The owner must be visible when this resource is evaluated; wrappers must provide
# Docker::Compose[$compose_name] in the final catalog. Missing owners fail compilation before declaring OCC commands.
# OCC waits for the visible owner; docker::compose_exec selects its nextcloud-aio-mastercontainer Compose service.
# The selected service must provide php occ for www-data through its PATH and working directory. Standard AIO documents
# OCC in nextcloud-aio-nextcloud, so this mastercontainer selection requires a deployment that supplies OCC there.
# Commands run as www-data with php occ, resolved inside the selected container.
# The mutation checks installation status before running; a missing/stopped container or incomplete installation fails.
# No OCC helper scripts or request files are installed.
# Commands and guards are Sensitive and output logging is disabled. Arguments remain visible through host/container
# process inspection. OCC config:system:set has no --sensitive option.
# Protect process access and Nextcloud logs/profiler.
#
# @example Leave maintenance mode when Nextcloud reports it active
#   docker::nextcloud_occ { 'maintenance-off':
#     command      => ['maintenance:mode', '--off'],
#     compose_name => 'nextcloud-aio',
#     unless       => ['status', '--exit-code'],
#   }
#
# @param command
#   OCC command and arguments without PHP or the OCC path. Use Sensitive[String] for arguments containing credentials.
#
# @param compose_name
#   Shared title of the deployment owner and its managed docker::compose resource, and the container's project label.
#   The standard AIO deployment uses nextcloud-aio, including for containers created by its mastercontainer.
#
# @param timeout
#   Maximum seconds for each command or guard, default 120. A Docker client timeout can leave PHP running.
#
# @param unless
#   Optional read-only OCC command. Exit 0 skips the mutation; other exit codes allow it. Default undef runs every time.
#   Guards also run during noop. Command exit 0 succeeds; other mutation exit codes fail the resource.
#
# @param unless_json
#   Optional expected JSON from unless, optionally Sensitive. Undef compares only exit status; otherwise parsed JSON
#   values are compared with object key ordering ignored and array order preserved. Requires unless with --output=json.
#
# @api public
define docker::nextcloud_occ (
  Array[Variant[String, Sensitive[String]], 1]           $command,
  Pattern[/\A[A-Za-z0-9_.-]+\z/]                         $compose_name,
  Integer[1]                                             $timeout      = 120,
  Optional[Array[Variant[String, Sensitive[String]], 1]] $unless       = undef,
  Optional[Variant[String, Sensitive[String]]]           $unless_json  = undef,
) {
  # Resolve the visible stack owner without assuming its wrapper body has already been evaluated.
  $compose_defined = defined(Docker::Compose[$compose_name])
  $compose_proxy_defined = defined(Docker::Compose_proxy[$compose_name])

  # The Nextcloud wrapper is optional; direct Compose deployments also work while that type is unavailable.
  $nextcloud_defined = defined('docker::nextcloud') and defined(Docker::Nextcloud[$compose_name])
  if ($compose_defined) {
    # Order OCC operations after the existing Compose stack.
    $compose_require = Docker::Compose[$compose_name]
    $compose_contract_fail_text = undef
  } elsif ($compose_proxy_defined) {
    # Order OCC operations after the existing Compose proxy wrapper.
    $compose_require = Docker::Compose_proxy[$compose_name]
    $compose_contract_fail_text = undef
  } elsif ($nextcloud_defined) {
    # Order OCC operations after the existing Nextcloud wrapper.
    $compose_require = Docker::Nextcloud[$compose_name]
    $compose_contract_fail_text = undef
  } else {
    # Report the missing stack owner before declaring OCC execution resources.
    $compose_contract_fail_text = "docker::nextcloud_occ requires Docker::Compose[${compose_name}], Docker::Compose_proxy[${compose_name}], or Docker::Nextcloud[${compose_name}] in the catalog." # lint:ignore:140chars
  }

  # Keep the deployment prerequisite and ordering central for every OCC caller.
  if ($compose_contract_fail_text == undef) {
    # The shared Compose executor provides Docker; the selected container must provide PHP and OCC.
    if (defined(Class['docker'])) {
      # Comparing JSON requires an OCC command that reads the current value.
      if ($unless_json == undef or $unless != undef) {
        # Keep the documented AIO OCC invocation shared by commands and guards.
        $occ_prefix = ['php', 'occ', '--no-interaction', '--no-ansi']
        $command_shell = concat($occ_prefix, $command).map |$argument| {
          # Unwrap credentials only while preparing the Sensitive command.
          $argument_correct = $argument ? {
            Sensitive => $argument.unwrap,
            default   => $argument,
          }
          stdlib::shell_escape($argument_correct)
        }.join(' ')

        # Compose checks the running container; OCC status verifies that installation has completed.
        $status_shell = concat($occ_prefix, ['status', '--output=json']).map |$argument| {
          stdlib::shell_escape($argument)
        }.join(' ')
        $ready_php = 'exit((json_decode(stream_get_contents(STDIN), true)["installed"] ?? false) === true ? 0 : 1);'
        $ready_shell = ['php', '-r', $ready_php].map |$argument| {
          stdlib::shell_escape($argument)
        }.join(' ')
        $command_correct = ['/bin/sh', '-c', Sensitive("${status_shell} | ${ready_shell} && ${command_shell}")]

        # JSON comparison is optional so ordinary OCC guards retain their native exit-code semantics.
        if ($unless != undef and $unless_json != undef) {
          # Canonicalize object keys recursively while retaining JSON scalar types and array ordering.
          $compare_php = join([
            '$sort = function ($value) use (&$sort) {',
            '    if (is_object($value)) {',
            '        $fields = get_object_vars($value); ksort($fields);',
            '        return (object) array_map($sort, $fields);',
            '    }',
            '    return is_array($value) ? array_map($sort, $value) : $value;',
            '};',
            '$actual = json_decode(stream_get_contents(STDIN), false, 512, JSON_THROW_ON_ERROR);',
            '$expected = json_decode($argv[1], false, 512, JSON_THROW_ON_ERROR);',
            'exit(json_encode($sort($actual)) === json_encode($sort($expected)) ? 0 : 1);',
          ], "\n")
          $expected_correct = $unless_json ? {
            Sensitive => $unless_json.unwrap,
            default   => $unless_json,
          }
          $compare_shell = ['php', '-r', $compare_php, $expected_correct].map |$argument| {
            stdlib::shell_escape($argument)
          }.join(' ')

          # Capture a successful OCC read before comparing; no current configuration is printed to Puppet.
          $read_shell = concat($occ_prefix, $unless).map |$argument| {
            # Sensitive guards use the same escaping as mutations.
            $argument_correct = $argument ? {
              Sensitive => $argument.unwrap,
              default   => $argument,
            }
            stdlib::shell_escape($argument_correct)
          }.join(' ')
          $unless_correct = ['/bin/sh', '-c', Sensitive(join([
            "CURRENT=\$(${read_shell}) || exit 1",
            "printf '%s' \"\$CURRENT\" | ${compare_shell}",
          ], "\n"))]
        } else {
          # Preserve native OCC guard exit codes; without a guard, run on every Puppet application.
          $unless_correct = $unless ? {
            undef   => undef,
            default => concat($occ_prefix, $unless),
          }
        }

        # Use the shared executor's existing Compose service selection and availability checks.
        docker::compose_exec { "docker_nextcloud_occ_${title}":
          command      => $command_correct,
          compose_name => $compose_name,
          service      => 'nextcloud-aio-mastercontainer',
          timeout      => $timeout,
          unless       => $unless_correct,
          user         => 'www-data',
          require      => $compose_require,
        }
      } else {
        fail('docker::nextcloud_occ unless_json requires an unless command.')
      }
    } else {
      fail('docker::nextcloud_occ requires the docker class before its declaration.')
    }
  } else {
    fail($compose_contract_fail_text)
  }
}
