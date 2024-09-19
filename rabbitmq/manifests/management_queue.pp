define rabbitmq::management_queue (
  Enum['present','absent']    $ensure     = present,
  Optional[Data]              $arguments  = undef,
  Boolean                     $durable    = true,
  Optional[String]            $type       = undef,
  String                      $vhost      = '/'
) {
  # Set delete command
  $find = "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} --format bash list queues | /usr/bin/grep ${name}"
  $delete = "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} delete queue name=${name}"

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

      # Set create command
      $create = "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} --vhost=${vhost} declare queue name=${name} durable=${durable_value}" #lint:ignore:140chars

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
        $create_correct = "${create} arguments='${arguments_json}'"
      } else {
        $arguments_json = '{}'
        $create_correct = $create
      }

      # Create queue
      exec { "rabbitmq_management_queue_${name}":
        command => $create_correct,
        unless  => $find,
        require => [Package['grep'], Exec['rabbitmq_management_admin_cli'], Exec["rabbitmq_management_vhost_${vhost_name}"]],
      }

      # Check if durable of the exange is the same
      exec { "rabbitmq_management_queue_${name}_durable":
        command => "${delete} && ${create_correct}",
        unless  => "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} list queues name durable | /usr/bin/grep ${name} | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep '|${name}|${durable_ucfirstvalue}|'", #lint:ignore:140chars
        require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_queue_${name}"]],
      }

      # Check if arguments of the exange is the same
      exec { "rabbitmq_management_queue_${name}_arguments":
        command => "${delete} && ${create_correct}",
        unless  => "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} --format raw_json list queues name arguments | sed 's/},{/'\\},\\\\n{'/g' | /usr/bin/grep '\"name\":\"${name}\"' | /usr/bin/grep '{\"arguments\":${arguments_json},\"name\":\"${name}\"}'", #lint:ignore:140chars
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
}
