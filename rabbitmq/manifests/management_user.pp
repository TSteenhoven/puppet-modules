# @summary Manages a RabbitMQ user and tags.
#
# lint:ignore:140chars
# This defined type requires `rabbitmq::management`. It creates or deletes a RabbitMQ user, optionally generates and stores a password in a matching managed local user's home directory, and reconciles RabbitMQ tags.
# lint:endignore
#
# @example Create a monitoring user
#   rabbitmq::management_user { 'monitoring':
#     password => lookup('rabbitmq::monitoring_password'),
#     tags     => ['monitoring'],
#   }
#
# @param ensure
#   Creates the user when `present`; deletes it when `absent`.
#
# @param password
#   Optional user password. `undef` generates a password when a matching `basic_settings::login_user` resource exists.
#
# @param tags
#   RabbitMQ user tags assigned to the account. The default is `['monitoring']`.
#
# @api public
define rabbitmq::management_user (
  Enum['present', 'absent'] $ensure   = present,
  Optional[String]          $password = undef,
  Array                     $tags     = ['monitoring'],
) {
  # Require the management interface before managing its broker accounts.
  if (defined(Class['rabbitmq::management'])) {
    # Escape the RabbitMQ username before building user commands and guards.
    $name_shell = stdlib::shell_escape($name)

    # Set commands
    $find = "/usr/sbin/rabbitmqctl --quiet list_user_limits --user ${name_shell}"

    case $ensure {
      'present': {
        # Require a local account only when its home must store a generated broker password.
        if ($password != undef or defined(Resource['basic_settings::login_user', $name])) {
          # Generate a password for a managed local account when none was supplied.
          if ($password == undef) {
            # Set defualt values
            $user_home = getparam(Resource['basic_settings::login_user', $name], 'home')
            $user_require = [Package['pwgen'], Rabbitmq::Plugin['rabbitmq_management']]

            # Escape password file path and ownership before writing the generated password.
            $password_file_shell = stdlib::shell_escape("${user_home}/.rabbitmq.password")
            $chown_spec_shell = stdlib::shell_escape("${name}:${name}")

            # Important, don't use --quiet here
            $user_add_script = "TMPPASS=\$(/usr/bin/pwgen -s 26 1); /usr/bin/printf %s \"\$TMPPASS\" > ${password_file_shell}; /usr/bin/chown ${chown_spec_shell} ${password_file_shell}; /usr/bin/chmod 600 ${password_file_shell}; /usr/bin/printf %s \"\$TMPPASS\" | /usr/sbin/rabbitmqctl add_user ${name_shell}" # lint:ignore:140chars

            # Escape the complete add-user script before passing it to bash -c.
            $user_add_script_shell = stdlib::shell_escape($user_add_script)
            $user_addd = "/usr/bin/bash -c ${user_add_script_shell}"
          } else {
            # Escape the supplied password before passing it to rabbitmqctl.
            $password_shell = stdlib::shell_escape($password)
            $user_addd = Sensitive.new("/usr/sbin/rabbitmqctl add_user ${name_shell} ${password_shell}") # Important, don't use --quiet here

            # Wait for the management plugin before creating the broker user.
            $user_require = Rabbitmq::Plugin['rabbitmq_management']
          }

          # Create user
          exec { "rabbitmq_management_user_${name}":
            command => $user_addd,
            unless  => $find,
            require => $user_require,
          }

          # Set tags
          if ($tags != undef) {
            # Escape tag names before building the tag command and grep chain.
            $user_tags_shell = $tags.map |$tag| { stdlib::shell_escape($tag) }
            $user_tags_join = join($user_tags_shell, ' ')
            $user_tags_search = join($user_tags_shell, ' | /usr/bin/grep ')
            exec { "rabbitmq_management_user_${name}_tags":
              command => "/usr/sbin/rabbitmqctl --quiet set_user_tags ${name_shell} ${user_tags_join}",
              unless  => "/usr/sbin/rabbitmqctl --quiet list_users --no-table-headers | /usr/bin/grep ${name_shell} | /usr/bin/cut -f2 | /usr/bin/grep ${user_tags_search}", # lint:ignore:140chars
              require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_user_${name}"]],
            }
          }
        } else {
          fail("User ${name} not present")
        }
      }
      'absent': {
        # Delete user
        exec { "rabbitmq_management_user_${name}":
          onlyif  => $find,
          command => "/usr/sbin/rabbitmqctl --quiet delete_user ${name_shell}",
        }
      }
      default: {
        fail('Unknown ensure: $ensure, must be present or absent')
      }
    }
  } else {
    fail('The rabbitmq::management class must be included before using the rabbitmq::management_user defined type.')
  }
}
