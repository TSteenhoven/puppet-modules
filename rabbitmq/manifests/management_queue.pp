# @summary Manages a RabbitMQ queue through rabbitmqadmin.
#
# lint:ignore:140chars
# This defined type requires `rabbitmq::management` and declares, deletes, or reconciles a queue in the selected vhost. It can manage durability, queue type, and arbitrary queue arguments.
# lint:endignore
#
# @example Create a quorum queue
#   rabbitmq::management_queue { 'jobs':
#     type => 'quorum',
#   }
#
# @param arguments
#   Optional RabbitMQ queue arguments. When `type` is set, it is merged into this hash as `x-queue-type`.
#
# @param durable
#   Controls queue durability. The default is `true`.
#
# @param ensure
#   Creates the queue when `present`; deletes it when `absent`.
#
# @param type
#   Optional queue type, such as `classic` or `quorum`.
#
# @param vhost
#   RabbitMQ virtual host where the queue is managed. The default is `/`.
#
# @api public
define rabbitmq::management_queue (
  Optional[Data]            $arguments = undef,
  Boolean                   $durable   = true,
  Enum['present', 'absent'] $ensure    = present,
  Optional[String]          $type      = undef,
  String                    $vhost     = '/',
) {
  if (defined(Class['rabbitmq::management'])) {
    # Escape rabbitmqadmin arguments before building queue commands and guards.
    $admin_config_path_shell = stdlib::shell_escape($rabbitmq::management::admin_config_path)
    $name_shell = stdlib::shell_escape($name)
    $name_arg_shell = stdlib::shell_escape("name=${name}")

    # Set delete command
    $find = "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} --format bash list queues | /usr/bin/grep ${name_shell}"
    $delete = "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} delete queue ${name_arg_shell}"

    case $ensure {
      'present': {
        # Get durable value
        if ($durable) {
          $durable_value = 'true'
          $durable_ucfirstvalue = 'True'
        } else {
          $durable_value = 'false'
          $durable_ucfirstvalue = 'False'
        }

        # Get vhost name
        if ($vhost == '/') {
          $vhost_name = 'default'
        } else {
          $vhost_name = $vhost
        }

        # Escape vhost, durable flag, and grep pattern before managing queue metadata.
        $vhost_option_shell = stdlib::shell_escape("--vhost=${vhost}")
        $durable_arg_shell = stdlib::shell_escape("durable=${durable_value}")
        $name_durable_pattern_shell = stdlib::shell_escape("|${name}|${durable_ucfirstvalue}|")

        # Set create command
        $create = "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} ${vhost_option_shell} declare queue ${name_arg_shell} ${durable_arg_shell}" # lint:ignore:140chars

        # Set type
        if ($type == undef) {
          $arguments_correct = $arguments
        } elsif ($arguments == undef) {
          $arguments_correct = { 'x-queue-type' => $type }
        } else {
          $arguments_correct = stdlib::merge({ 'x-queue-type' => $type }, $arguments)
        }

        # Check if arguments is not given
        if ($arguments_correct != undef) {
          # Convert de hash to array and sort by key
          $arguments_pairs = $arguments_correct.keys.map |$key| { [$key, $arguments_correct[$key]] }
          $arguments_sorted = stdlib::sort_by($arguments_pairs) |$pair| { $pair[0] }

          # Convert aray back to json
          $arguments_json = stdlib::to_json($arguments_sorted.reduce({}) |$result, $pair| {
              $result + { $pair[0] => $pair[1] }
          })

          # Escape the JSON arguments before appending them to rabbitmqadmin.
          $arguments_arg_shell = stdlib::shell_escape("arguments=${arguments_json}")
          $create_correct = "${create} ${arguments_arg_shell}"
        } else {
          $arguments_json = '{}'
          $create_correct = $create
        }

        # Escape queue argument check patterns before passing them to grep.
        $arguments_pattern_shell = stdlib::shell_escape("{\"arguments\":${arguments_json},\"name\":\"${name}\"}")
        $name_json_pattern_shell = stdlib::shell_escape("\"name\":\"${name}\"")

        # Create queue
        exec { "rabbitmq_management_queue_${name}":
          command => $create_correct,
          unless  => $find,
          require => [Package['grep'], Exec['rabbitmq_management_admin_cli'], Exec["rabbitmq_management_vhost_${vhost_name}"]],
        }

        # Check if durable of the exchange is the same
        exec { "rabbitmq_management_queue_${name}_durable":
          command => "${delete} && ${create_correct}",
          unless  => "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} list queues name durable | /usr/bin/grep ${name_shell} | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep ${name_durable_pattern_shell}", # lint:ignore:140chars
          require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_queue_${name}"]],
        }

        # Check if arguments of the exchange is the same
        exec { "rabbitmq_management_queue_${name}_arguments":
          command => "${delete} && ${create_correct}",
          unless  => "/usr/sbin/rabbitmqadmin --config ${admin_config_path_shell} --format raw_json list queues name arguments | sed 's/},{/'\\},\\\\n{'/g' | /usr/bin/grep ${name_json_pattern_shell} | /usr/bin/grep ${arguments_pattern_shell}", # lint:ignore:140chars
          require => [Package['coreutils'], Package['grep'], Package['sed'], Exec["rabbitmq_management_queue_${name}"]],
        }
      }

      'absent': {
        # Delete queue
        exec { "rabbitmq_management_queue_${name}":
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
    fail('The rabbitmq::management class must be included before using the rabbitmq::management_queue defined type.')
  }
}
