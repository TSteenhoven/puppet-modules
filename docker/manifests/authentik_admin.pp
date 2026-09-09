# @summary Creates, updates, or removes an Authentik admin user in a Docker Compose stack.
#
# lint:ignore:140chars
# This defined type talks directly to the running Authentik `server` Compose service with `ak shell`. When `ensure` is `present`, it creates the user when missing, activates existing users, updates the requested email and password, and ensures membership of a superuser group. When `ensure` is `absent`, it removes the requested user. The password is accepted as `Sensitive[String]` and the generated Puppet `exec` command and guard are also marked sensitive so the secret is not written to normal Puppet output.
# lint:endignore
#
# lint:ignore:140chars
# Declare `docker::authentik` or an equivalent `docker::compose` stack with the same `compose_name`. The stack must already be running; this resource does not start or restart Authentik.
# lint:endignore
#
# @example Create or repair an Authentik admin account
#   docker::authentik_admin { 'example.admin':
#     compose_name => 'authentik',
#     email        => 'info@example.org',
#     password     => Sensitive('replace-with-admin-password'),
#     require      => Docker::Authentik['authentik'],
#   }
#
# @example Remove the bundled Authentik bootstrap admin account
#   docker::authentik_admin { 'remove-akadmin':
#     ensure       => absent,
#     compose_name => 'authentik',
#     username     => 'akadmin',
#     require      => Docker::Authentik['authentik'],
#   }
#
# @param compose_name
#   Title of the managed `docker::compose` resource for the Authentik stack.
#
# @param email
#   Email address to set on the Authentik user. Required when `ensure` is `present`; ignored when `ensure` is `absent`.
#
# @param ensure
#   Controls whether the Authentik user is present or absent.
#
# @param group_name
#   Authentik group that should grant superuser access to the managed user.
#
# @param password
# lint:ignore:140chars
#   Password assigned to the Authentik user. Required when `ensure` is `present`; ignored when `ensure` is `absent`. Supply it from Hiera or a profile as a `Sensitive[String]` value.
# lint:endignore
#
# @param timeout
#   Maximum time in seconds for each Docker Compose operation.
#
# @param username
#   Authentik username to manage. Defaults to the resource title.
#
# @api public
define docker::authentik_admin (
  Pattern[/\A[A-Za-z0-9_.-]+\z/]             $compose_name,
  Optional[Pattern[/\A[^\r\n]+\z/]]          $email        = undef,
  Enum['present', 'absent']                  $ensure       = present,
  Pattern[/\A[^\r\n]+\z/]                    $group_name   = 'authentik Admins',
  Optional[Sensitive[String]]                $password     = undef,
  Integer[1]                                 $timeout      = 120,
  Optional[Pattern[/\A[A-Za-z0-9@._+-]+\z/]] $username     = undef,
) {
  # Resolve the best currently visible catalog anchor without assuming wrapper bodies have already been evaluated.
  $compose_defined = defined(Docker::Compose[$compose_name])
  $compose_proxy_defined = defined(Docker::Compose_proxy[$compose_name])
  $authentik_defined = defined(Docker::Authentik[$compose_name])
  if ($compose_defined) {
    $compose_require = Docker::Compose[$compose_name]
    $compose_contract_fail_text = undef
  } elsif ($compose_proxy_defined) {
    $compose_require = Docker::Compose_proxy[$compose_name]
    $compose_contract_fail_text = undef
  } elsif ($authentik_defined) {
    $compose_require = Docker::Authentik[$compose_name]
    $compose_contract_fail_text = undef
  } else {
    $compose_contract_fail_text = "docker::authentik_admin requires Docker::Compose[${compose_name}], Docker::Compose_proxy[${compose_name}], or Docker::Authentik[${compose_name}] in the catalog." # lint:ignore:140chars
  }

  if ($compose_contract_fail_text == undef) {
    # Resolve the running container from Docker labels at execution time instead of duplicating Compose-owned paths here.
    $service = 'server'

    # Resolve the optional username before validation and command construction.
    $username_correct = $username ? {
      undef   => $title,
      default => $username,
    }

    # Validate present-only input only when the user is meant to exist.
    $present_input_fail_text = $ensure ? {
      'present' => $email ? {
        undef   => 'docker::authentik_admin requires email when ensure => present.',
        default => $password ? {
          undef   => 'docker::authentik_admin requires password when ensure => present.',
          default => undef,
        },
      },
      default => undef,
    }

    if ($present_input_fail_text == undef) {
      # Validate title-derived usernames before using them in the generated command.
      if ($username_correct =~ /\A[A-Za-z0-9@._+-]+\z/) {
        # Escape common dynamic shell words at the Docker CLI boundary.
        $compose_name_shell = stdlib::shell_escape($compose_name)
        $service_shell = stdlib::shell_escape($service)
        $username_shell = stdlib::shell_escape($username_correct)

        # Locate the running Compose service container by Docker labels so no compose path values are duplicated in this defined type.
        $container_lookup_command = join([
            'container_id=$(/usr/bin/docker ps',
            "--filter label=com.docker.compose.project=${compose_name_shell}",
            "--filter label=com.docker.compose.service=${service_shell}",
            "--format '{{.ID}}'",
            '| /usr/bin/head -n 1)',
        ], ' ')
        $container_required_command = 'test -n "$container_id" || exit 1'

        if ($ensure == present) {
          $password_unwrapped = $password.unwrap
          if ($password_unwrapped =~ /\A[^\r\n]+\z/) {
            # Pass managed Authentik values as environment variables to keep the Python block static.
            $email_shell = stdlib::shell_escape($email)
            $group_name_shell = stdlib::shell_escape($group_name)
            $password_shell = stdlib::shell_escape($password_unwrapped)
            $authentik_env_args = join([
                "-e AK_ADMIN_USERNAME=${username_shell}",
                "-e AK_ADMIN_EMAIL=${email_shell}",
                "-e AK_ADMIN_PASSWORD=${password_shell}",
                "-e AK_ADMIN_GROUP=${group_name_shell}",
            ], ' ')

            # The present guard confirms the user, password, active state, email, and superuser group membership.
            $check_python = join([
                'import os',
                'from authentik.core.models import Group, User',
                '',
                'username = os.environ["AK_ADMIN_USERNAME"]',
                'email = os.environ["AK_ADMIN_EMAIL"]',
                'password = os.environ["AK_ADMIN_PASSWORD"]',
                'group_name = os.environ["AK_ADMIN_GROUP"]',
                '',
                'try:',
                '    user = User.objects.get(username=username)',
                'except User.DoesNotExist:',
                '    raise SystemExit(1)',
                '',
                'if not user.is_active:',
                '    raise SystemExit(1)',
                'if user.email != email:',
                '    raise SystemExit(1)',
                'if not user.check_password(password):',
                '    raise SystemExit(1)',
                'if not user.groups.filter(name=group_name, is_superuser=True).exists():',
                '    raise SystemExit(1)',
            ], "\n")

            # The present update path creates missing objects and only mutates existing fields that drifted.
            $update_python = join([
                'import os',
                'from authentik.core.models import Group, User',
                '',
                'username = os.environ["AK_ADMIN_USERNAME"]',
                'email = os.environ["AK_ADMIN_EMAIL"]',
                'password = os.environ["AK_ADMIN_PASSWORD"]',
                'group_name = os.environ["AK_ADMIN_GROUP"]',
                '',
                'user, created = User.objects.get_or_create(',
                '    username=username,',
                '    defaults={',
                '        "path": "users",',
                '        "name": username,',
                '        "email": email,',
                '    },',
                ')',
                '',
                'user.name = user.name or username',
                'user.path = user.path or "users"',
                'user.email = email',
                'user.is_active = True',
                'if created or not user.check_password(password):',
                '    user.set_password(password)',
                'user.save()',
                '',
                'group, group_created = Group.objects.get_or_create(',
                '    name=group_name,',
                '    defaults={"is_superuser": True},',
                ')',
                'if not group.is_superuser:',
                '    group.is_superuser = True',
                '    group.save()',
                'if not user.groups.filter(pk=group.pk).exists():',
                '    user.groups.add(group)',
                '',
                'print("authentik admin user %s is active and has superuser access through %s" % (username, group.name))',
            ], "\n")
          } else {
            fail('docker::authentik_admin password must not be empty or contain newlines.')
          }
        } else {
          # For absent users, only the username is needed and email or password input is intentionally ignored.
          $authentik_env_args = "-e AK_ADMIN_USERNAME=${username_shell}"

          # The absent guard succeeds when the requested Authentik user no longer exists.
          $check_python = join([
              'import os',
              'from authentik.core.models import User',
              '',
              'username = os.environ["AK_ADMIN_USERNAME"]',
              '',
              'if User.objects.filter(username=username).exists():',
              '    raise SystemExit(1)',
          ], "\n")

          # The absent update path deletes the requested user and leaves the run idempotent when already absent.
          $update_python = join([
              'import os',
              'from authentik.core.models import User',
              '',
              'username = os.environ["AK_ADMIN_USERNAME"]',
              '',
              'deleted, _ = User.objects.filter(username=username).delete()',
              'if deleted:',
              '    print("authentik user %s removed" % username)',
              'else:',
              '    print("authentik user %s already absent" % username)',
          ], "\n")
        }

        # Build the Docker exec command and heredocs for Puppet's shell provider so Python code is sent through stdin.
        $docker_exec_command = join([
            '/usr/bin/docker exec -i',
            $authentik_env_args,
            '"$container_id"',
            'ak shell',
        ], ' ')
        $check_command = join([
            $container_lookup_command,
            $container_required_command,
            "${docker_exec_command} <<'PY'",
            $check_python,
            'PY',
        ], "\n")
        $update_command = join([
            $container_lookup_command,
            $container_required_command,
            "${docker_exec_command} <<'PY'",
            $update_python,
            'PY',
        ], "\n")

        # Run the Authentik mutation only when the guard detects drift.
        exec { "docker_authentik_admin_${ensure}_${compose_name}_${username_correct}":
          command   => Sensitive.new($update_command),
          logoutput => false,
          provider  => shell,
          require   => $compose_require,
          timeout   => $timeout,
          unless    => Sensitive.new($check_command),
        }
      } else {
        fail('docker::authentik_admin usernames may only contain letters, numbers, at signs, dots, underscores, plus signs, and hyphens.')
      }
    } else {
      fail($present_input_fail_text)
    }
  } else {
    fail($compose_contract_fail_text)
  }
}
