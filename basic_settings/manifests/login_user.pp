# @summary Manages a local login user, home directory, SSH material, and audit coverage.
#
# This defined type creates or removes a local user and optional matching group, manages a tightly permissioned home
# directory, SSH authorized keys and private key material, optional private shell startup files, and audit rules for the
# user's `.ssh` tree when auditd is available. Passwords are handled as `Sensitive` values and generated files are
# restricted to the managed user.
#
# @example Create a key-only user with a managed home directory
#   basic_settings::login_user { 'deploy':
#     gid             => 2000,
#     home            => '/home/deploy',
#     password        => Sensitive('!!'),
#     uid             => 2000,
#     authorized_keys => ['ssh-ed25519 AAAA... deploy@example'],
#   }
#
# @param gid
#   Primary group ID for the user and for the matching group when `disable_group` is `false`.
#
# @param home
#   Absolute home directory path managed for the user when `home_enable` is `true`.
#
# @param password
#   Password hash or lock marker passed to the Puppet `user` resource as a `Sensitive[String]`.
#
# @param uid
#   Numeric user ID for the account.
#
# @param authorized_keys
#   Optional list of SSH public keys written to `authorized_keys`. `undef` purges SSH keys through the user resource; an
#   empty array creates an empty managed file.
#
# @param bash_aliases
#   Optional content for `.bash_aliases`. Use `default` to render the module default template.
#
# @param bash_profile
#   Optional content for `.profile`. Use `default` to render the module default template.
#
# @param bashrc
#   Optional content for `.bashrc`. Use `default` to render the module default template, with a root-specific variant
#   for the `root` account.
#
# @param disable_group
#   Prevents management of a matching group when `true`. The default is `false`.
#
# @param ensure
#   Controls whether the user and related files are present or absent.
#
# @param groups
#   Supplementary groups assigned to the user. The default is an empty list.
#
# @param home_enable
#   Controls whether the home directory and SSH/profile files are managed.
#
# @param home_force
#   Passed to managed home directory file resources. Use with care because it can force removal of unmanaged content
#   when combined with purge/recurse options.
#
# @param home_purge
#   Purges unmanaged files below the home directory when `true` and recursion is enabled.
#
# @param home_recurse
#   Recurses through the home directory when `true`. Recursive management uses non-executable file modes while keeping
#   directories traversable.
#
# @param home_source
#   Optional file source used to seed the home directory. Must start with `puppet:///`, `file:///`, or `https://`.
#
# @param password_max_age
#   Optional password maximum age. `undef` selects a default based on whether the account has SSH keys or a locked
#   password.
#
# @param private_key
#   Optional file source for `${home}/.ssh/private.key`. Must start with `puppet:///`, `file:///`, or `https://`; the
#   file is written with mode `0600`.
#
# @param shell
#   Login shell for the account. The default is `/bin/bash`.
#
# @api public
define basic_settings::login_user (
  Integer                   $gid,
  String                    $home,
  Sensitive[String]         $password,
  Integer                   $uid,
  Optional[Array]           $authorized_keys  = undef,
  Optional[String]          $bash_aliases     = undef,
  Optional[String]          $bash_profile     = undef,
  Optional[String]          $bashrc           = undef,
  Boolean                   $disable_group    = false,
  Enum['present', 'absent'] $ensure           = present,
  Array                     $groups           = [],
  Boolean                   $home_enable      = true,
  Boolean                   $home_force       = false,
  Boolean                   $home_purge       = false,
  Boolean                   $home_recurse     = false,
  Optional[String]          $home_source      = undef,
  Optional[Integer]         $password_max_age = undef,
  Optional[String]          $private_key      = undef,
  String                    $shell            = '/bin/bash',
) {
  # Keep valid source input on the main path; invalid schemes are exceptional.
  if ($home_source == undef or $home_source =~ /(?i:\A(?:puppet:\/\/\/|file:\/\/\/|https:\/\/))/) {
    # Reject unsupported private-key sources before managing account files.
    if ($private_key == undef or $private_key =~ /(?i:\A(?:puppet:\/\/\/|file:\/\/\/|https:\/\/))/) {
      # Set variables
      if (defined(Class['basic_settings::login'])) {
        # Inherit the environment, hostname, and terminal-message policy from the login class.
        $environment = $basic_settings::login::environment
        $hostname = $basic_settings::login::hostname
        $mesg_disable = $basic_settings::login::mesg_disable
      } else {
        # Use standalone login defaults and the host's reported short name.
        $environment = 'production'
        $hostname = $facts['networking']['hostname']
        $mesg_disable = true
      }

      # Set authorized keys state
      if ($authorized_keys != undef) {
        # Keep the explicitly supplied authorized-key collection under resource-level management.
        $authorized_keys_purge = false

        # Distinguish an explicitly empty key list from a supplied set of login keys.
        if (empty($authorized_keys)) {
          # Mark an explicitly empty collection as having no login keys.
          $authorized_keys_empty = true
        } else {
          # Record that the supplied collection contains login keys.
          $authorized_keys_empty = false
        }
      } else {
        # Purge unmanaged keys when no authorized-key collection is supplied.
        $authorized_keys_purge = true
        $authorized_keys_empty = true
      }

      # Unwrap only for control-flow decisions; the user resource still receives the Sensitive value.
      $password_unwrapped = $password.unwrap

      # Get password max age
      if ($authorized_keys_empty) {
        # Use a default password age only when the caller has not chosen one.
        if ($password_max_age == undef) {
          # Avoid password expiry for a locked account; otherwise apply the default maximum age.
          if ($password_unwrapped == '!!') {
            # Avoid password-expiry handling for a locked password.
            $password_max_age_correct = -1
          } else {
            # Default password-based logins to an annual password change.
            $password_max_age_correct = 365
          }
        } else {
          # Preserve the caller's password-expiry interval.
          $password_max_age_correct = $password_max_age
        }
      } elsif ($password_max_age == undef) {
        # Leave password expiry disabled for the default key-based login path.
        $password_max_age_correct = -1
      } else {
        # Preserve the caller's password-expiry interval.
        $password_max_age_correct = $password_max_age
      }

      # Create only user group when group is disabled
      if (!$disable_group) {
        group { $name:
          ensure => $ensure,
          gid    => $gid,
        }
      }

      # Create user
      user { $name:
        ensure             => $ensure,
        uid                => $uid,
        gid                => $gid,
        groups             => $groups,
        shell              => $shell,
        home               => $home,
        managehome         => false,
        password           => $password,
        password_max_age   => $password_max_age_correct,
        password_warn_days => 31,
        purge_ssh_keys     => $authorized_keys_purge,
      }

      # Create the group before its user and reverse that order for account removal.
      if ($ensure == present) {
        Group[$name] -> User[$name]
      } else {
        User[$name] -> Group[$name]
      }

      # Manage home-directory content only when home management is requested.
      if ($home_enable) {
        # Preserve home directories during account removal while removing managed SSH and profile files.
        $home_directory_ensure = $ensure ? {
          'absent' => undef,
          default  => directory,
        }
        $home_file_ensure = $ensure ? {
          'absent' => 'absent',
          default  => present,
        }

        # Recursive home management uses a non-executable file mode; Puppet keeps directories traversable.
        $home_mode = $home_recurse ? {
          true    => '0600',
          default => '0700',
        }

        # Make home dir
        if ($home_source != undef) {
          file { $home:
            ensure  => $home_directory_ensure,
            owner   => $uid,
            group   => $gid,
            force   => $home_force,
            purge   => $home_purge,
            recurse => $home_recurse,
            source  => $home_source,
            mode    => $home_mode,
          }
        } else {
          file { $home:
            ensure  => $home_directory_ensure,
            owner   => $uid,
            group   => $gid,
            force   => $home_force,
            purge   => $home_purge,
            recurse => $home_recurse,
            mode    => $home_mode,
          }
        }

        # Create ssh dir
        file { "${home}/.ssh":
          ensure  => $home_directory_ensure,
          owner   => $uid,
          group   => $gid,
          mode    => '0700',
          require => File[$home],
        }

        # Create authorized_keys file
        if ($authorized_keys != undef) {
          file { "${home}/.ssh/authorized_keys":
            ensure  => $home_file_ensure,
            content => Sensitive.new(join($authorized_keys, "\n")),
            mode    => '0600',
            owner   => $uid,
            group   => $gid,
            require => File[$home],
          }
        }

        # Create private key file
        if ($private_key != undef) {
          file { "${home}/.ssh/private.key":
            ensure  => $home_file_ensure,
            source  => $private_key,
            mode    => '0600',
            owner   => $uid,
            group   => $gid,
            require => File[$home],
          }
        }

        # Create profile file
        if ($bash_profile != undef) {
          # Choose the managed login profile or use the supplied profile content.
          if ($bash_profile == 'default') {
            # Render the shared login profile when no custom profile is supplied.
            $bash_profile_correct = template('basic_settings/login/bash/profile')
          } else {
            # Keep the caller's custom login profile.
            $bash_profile_correct = $bash_profile
          }

          # Write the selected login profile with permissions restricted to its account.
          file { "${home}/.profile":
            ensure  => $home_file_ensure,
            content => $bash_profile_correct,
            owner   => $uid,
            group   => $gid,
            mode    => '0600',
            require => File[$home],
          }
        }

        # Create bashrc file
        if ($bashrc != undef) {
          # Choose the managed Bash configuration or use the supplied content.
          if ($bashrc == 'default') {
            # Use the root-specific shell defaults for the root account.
            if ($name == 'root') {
              # Use the root-specific interactive shell defaults.
              $bash_rc_correct = template('basic_settings/login/bash/rc-root')
            } else {
              # Use the regular-user interactive shell defaults.
              $bash_rc_correct = template('basic_settings/login/bash/rc')
            }
          } else {
            # Keep the caller's custom interactive shell configuration.
            $bash_rc_correct = $bashrc
          }

          # Apply the selected interactive shell setup after resolving account-specific defaults.
          file { "${home}/.bashrc":
            ensure  => $home_file_ensure,
            content => $bash_rc_correct,
            owner   => $uid,
            group   => $gid,
            mode    => '0600',
            require => File[$home],
          }
        }

        # Create bash aliases file
        if ($bash_aliases != undef) {
          # Choose the managed alias set or use the supplied alias content.
          if ($bash_aliases == 'default') {
            # Render the shared shell aliases when no custom aliases are supplied.
            $bash_aliases_correct = template('basic_settings/login/bash/aliases')
          } else {
            # Keep the caller's custom shell aliases.
            $bash_aliases_correct = $bash_aliases
          }

          # Keep the selected aliases private to this account.
          file { "${home}/.bash_aliases":
            ensure  => $home_file_ensure,
            content => $bash_aliases_correct,
            owner   => $uid,
            group   => $gid,
            mode    => '0600',
            require => File[$home],
          }
        }

        # Create audit rules
        if (defined(Package['auditd'])) {
          basic_settings::security_audit { "${name}-ssh":
            ensure => $ensure,
            rules  => [
              "-a always,exit -F arch=b32 -F dir=${home}/.ssh -F perm=r -F auid!=unset -F key=ssh",
              "-a always,exit -F arch=b64 -F dir=${home}/.ssh -F perm=r -F auid!=unset -F key=ssh",
              "-a always,exit -F arch=b32 -F dir=${home}/.ssh -F perm=wa -F key=ssh",
              "-a always,exit -F arch=b64 -F dir=${home}/.ssh -F perm=wa -F key=ssh",
            ],
          }
        }
      }
    } else {
      fail('basic_settings::login_user private_key must start with puppet:///, file:///, or https://')
    }
  } else {
    fail('basic_settings::login_user home_source must start with puppet:///, file:///, or https://')
  }
}
