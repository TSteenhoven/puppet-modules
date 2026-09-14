# @summary Manages a RabbitMQ binding through rabbitmqadmin.
#
# lint:ignore:140chars
# This defined type requires `rabbitmq::management` and declares or deletes a binding between an exchange and queue. It also reconciles the routing key when one is supplied.
# lint:endignore
#
# @example Bind an exchange to a queue
#   rabbitmq::management_binding { 'failure_binding':
#     source      => 'failure_exchange',
#     destination => 'failure_messages',
#     routing_key => 'failure',
#   }
#
# @param destination
#   Binding destination, usually a queue name.
#
# @param source
#   Binding source, usually an exchange name.
#
# @param ensure
#   Creates the binding when `present`; deletes it when `absent`.
#
# @param routing_key
#   Optional routing key for the binding.
#
# @param vhost
#   RabbitMQ virtual host where the binding is managed. The default is `/`.
#
# @api public
define rabbitmq::management_binding (
  String                    $destination,
  String                    $source,
  Enum['present', 'absent'] $ensure      = present,
  Optional[String]          $routing_key = undef,
  String                    $vhost       = '/',
) {
  # Require the management interface before using rabbitmqadmin to manage bindings.
  if (defined(Class['rabbitmq::management'])) {
    # Escape rabbitmqadmin arguments before building binding commands and guards.
    $admin_config_path_shell = stdlib::shell_escape($rabbitmq::management::admin_config_path)
    $vhost_option_shell = stdlib::shell_escape("--vhost=${vhost}")
    $source_arg_shell = stdlib::shell_escape("source=${source}")
    $destination_arg_shell = stdlib::shell_escape("destination=${destination}")
    $binding_pattern_shell = stdlib::shell_escape("|${source}|${destination}|")

    # Set commands
    $find = "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} ${vhost_option_shell} list bindings source destination | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep ${binding_pattern_shell}" # lint:ignore:140chars
    $delete = "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} delete binding ${source_arg_shell} ${destination_arg_shell}"

    case $ensure {
      'present': {
        # Get vhost name
        if ($vhost == '/') {
          # Give the root virtual host a readable name in management resource identifiers.
          $vhost_name = 'default'
        } else {
          # Keep the non-root virtual host name in management resource identifiers.
          $vhost_name = $vhost
        }

        # Set create command
        $create = "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} ${vhost_option_shell} declare binding ${source_arg_shell} ${destination_arg_shell}" # lint:ignore:140chars

        # Add a routing-key argument only when the caller supplied one.
        if ($routing_key != undef) {
          # Escape the optional routing key argument before appending it to rabbitmqadmin.
          $routing_key_arg_shell = stdlib::shell_escape("routing_key=${routing_key}")
          $create_correct = "${create} ${routing_key_arg_shell}"
        } else {
          # Keep the supplied binding command when no routing key needs to be appended.
          $create_correct = $create
        }

        # Create binding
        exec { "rabbitmq_management_binding_${name}":
          command => $create_correct,
          unless  => $find,
          require => [
            Package[
              'coreutils',
              'grep',
            ],
            Exec['rabbitmq_management_admin_cli', "rabbitmq_management_vhost_${vhost_name}"],
          ],
        }

        # Check if routing key of the binding is the same
        if ($routing_key != undef) {
          # Escape the routing key check pattern before passing it to grep.
          $binding_routing_key_pattern_shell = stdlib::shell_escape("|${source}|${destination}|${routing_key}|")
          exec { "rabbitmq_management_binding_${name}_routing_key":
            command => "${delete} && ${create_correct}",
            unless  => "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} ${vhost_option_shell} list bindings source destination routing_key | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep ${binding_routing_key_pattern_shell}", # lint:ignore:140chars
            require => [Package['coreutils', 'grep'], Exec["rabbitmq_management_vhost_${vhost_name}"]],
          }
        }
      }
      'absent': {
        # Delete binding
        exec { "rabbitmq_management_binding_${name}":
          onlyif  => $find,
          command => $delete,
          require => [Package['coreutils', 'grep'], Exec['rabbitmq_management_admin_cli']],
        }
      }
      default: {
        fail('Unknown ensure: $ensure, must be present or absent')
      }
    }
  } else {
    fail('The rabbitmq::management class must be included before using the rabbitmq::management_binding defined type.')
  }
}
