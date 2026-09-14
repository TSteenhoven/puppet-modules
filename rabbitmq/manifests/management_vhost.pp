# @summary Manages a RabbitMQ virtual host and default queue type.
#
# This defined type requires `rabbitmq::management` and creates, deletes, or reconciles a virtual host's default queue type metadata.
#
# @example Create a quorum-default vhost
#   rabbitmq::management_vhost { 'app':
#     type => 'quorum',
#   }
#
# @param ensure
#   Creates the vhost when `present`; deletes it when `absent`.
#
# @param type
#   Default queue type set on the vhost. The default is `classic`.
#
# @api public
define rabbitmq::management_vhost (
  Enum['present', 'absent'] $ensure = present,
  String                    $type   = 'classic',
) {
  # Require the management interface before using rabbitmqadmin to manage virtual hosts.
  if (defined(Class['rabbitmq::management'])) {
    # Get exec name
    if ($name == '/') {
      # Give the root virtual host a readable exec resource identifier.
      $exec_name = 'default'
    } else {
      # Keep the non-root virtual host name in exec resource identifiers.
      $exec_name = $name
    }

    # Escape vhost arguments before passing them to rabbitmqctl and grep.
    $name_shell = stdlib::shell_escape($name)
    $type_shell = stdlib::shell_escape($type)
    $name_type_pattern_shell = stdlib::shell_escape("${name}|${type}")

    # Set commands
    $find = "/usr/sbin/rabbitmqctl --quiet list_vhosts --no-table-headers name | /usr/bin/grep ${name_shell}"

    case $ensure {
      'present': {
        # Check if vhost exists
        exec { "rabbitmq_management_vhost_${exec_name}":
          command => "/usr/sbin/rabbitmqctl add_vhost ${name_shell} --default-queue-type ${type_shell}",
          unless  => $find,
          require => [Package['grep'], Rabbitmq::Plugin['rabbitmq_management']],
        }

        # Check if type of the vhost is the same
        exec { "rabbitmq_management_vhost_${exec_name}_type":
          command => "/usr/sbin/rabbitmqctl update_vhost_metadata ${name_shell} --default-queue-type ${type_shell}",
          unless  => "/usr/sbin/rabbitmqctl --quiet list_vhosts --no-table-headers name default_queue_type | /usr/bin/grep ${name_shell} | /usr/bin/tr '[:blank:]' '|' | /usr/bin/grep ${name_type_pattern_shell}", # lint:ignore:140chars
          require => [Package['coreutils', 'grep'], Exec["rabbitmq_management_vhost_${exec_name}"]],
        }
      }
      'absent': {
        # Delete vhost
        exec { "rabbitmq_management_vhost_${exec_name}":
          onlyif  => $find,
          command => "/usr/sbin/rabbitmqctl --quiet delete_vhost ${name_shell}",
          require => [Package['grep'], Rabbitmq::Plugin['rabbitmq_management']],
        }
      }
      default: {
        fail('Unknown ensure: $ensure, must be present or absent')
      }
    }
  } else {
    fail('The rabbitmq::management class must be included before using the rabbitmq::management_vhost defined type.')
  }
}
