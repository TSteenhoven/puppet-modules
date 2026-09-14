# @summary Manages a RabbitMQ exchange through rabbitmqadmin.
#
# This defined type requires `rabbitmq::management` and declares, deletes, or reconciles an exchange in the selected vhost.
#
# @example Create a direct exchange
#   rabbitmq::management_exchange { 'failure_exchange':
#     type => 'direct',
#   }
#
# @param ensure
#   Creates the exchange when `present`; deletes it when `absent`.
#
# @param type
#   Exchange type passed to RabbitMQ, such as `direct`, `topic`, or `fanout`.
#
# @param vhost
#   RabbitMQ virtual host where the exchange is managed. The default is `/`.
#
# @api public
define rabbitmq::management_exchange (
  Enum['present', 'absent'] $ensure = present,
  String                    $type   = 'direct',
  String                    $vhost  = '/',
) {
  # Require the management interface before using rabbitmqadmin to manage exchanges.
  if (defined(Class['rabbitmq::management'])) {
    # Escape rabbitmqadmin arguments before building exchange commands and guards.
    $admin_config_path_shell = stdlib::shell_escape($rabbitmq::management::admin_config_path)
    $name_shell = stdlib::shell_escape($name)
    $name_arg_shell = stdlib::shell_escape("name=${name}")

    # Set commands
    $find = "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} --format bash list exchanges | /usr/bin/grep ${name_shell}"
    $delete = "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} delete exchange ${name_arg_shell}"

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

        # Escape vhost, type, and grep pattern before managing exchange metadata.
        $vhost_option_shell = stdlib::shell_escape("--vhost=${vhost}")
        $type_arg_shell = stdlib::shell_escape("type=${type}")
        $name_type_pattern_shell = stdlib::shell_escape("|${name}|${type}|")

        # Set create command
        $create = "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} ${vhost_option_shell} declare exchange ${name_arg_shell} ${type_arg_shell}" # lint:ignore:140chars

        # Create exchange
        exec { "rabbitmq_management_exchange_${name}":
          command => $create,
          unless  => $find,
          require => [Package['grep'], Exec['rabbitmq_management_admin_cli', "rabbitmq_management_vhost_${vhost_name}"]],
        }

        # Check if type of the exchange is the same
        exec { "rabbitmq_management_exchange_${name}_type":
          command => "${delete} && ${create}",
          unless  => "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} list exchanges name type | /usr/bin/grep ${name_shell} | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep ${name_type_pattern_shell}", # lint:ignore:140chars
          require => [Package['coreutils', 'grep'], Exec["rabbitmq_management_exchange_${name}"]],
        }
      }
      'absent': {
        # Delete exchange
        exec { "rabbitmq_management_exchange_${name}":
          onlyif  => $find,
          command => $delete,
          require => [Package['grep'], Exec['rabbitmq_management_admin_cli']],
        }
      }
      default: {
        fail('Unknown ensure: $ensure, must be present or absent')
      }
    }
  } else {
    fail('The rabbitmq::management class must be included before using the rabbitmq::management_exchange defined type.')
  }
}
