define rabbitmq::management_binding (
  String                      $source,
  String                      $destination,
  Enum['present','absent']    $ensure         = present,
  String                      $vhost          = '/',
  Optional[String]            $routing_key    = undef
) {
  # Set commands
  $find = "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} --vhost=${vhost} list bindings source destination | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep '|${source}|${destination}|'"
  $delete = "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} delete binding source=${source} destination=${destination}"

  case $ensure {
    'present': {
      # Get vhost name
      if ($vhost == '/') {
        $vhost_name = 'default'
      } else {
        $vhost_name = $vhost
      }

      # Set create command
      $create = "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} --vhost=${vhost} declare binding source=${source} destination=${destination}"
      if ($routing_key == undef) {
        $create_correct = $create
      } else {
        $create_correct = "${create} routing_key=${routing_key}"
      }

      # Create binding
      exec { "rabbitmq_management_binding_${name}":
        command => $create_correct,
        unless  => $find,
        require => [Package['coreutils'], Package['grep'], Exec['rabbitmq_management_admin_cli'], Exec["rabbitmq_management_vhost_${vhost_name}"]],
      }

      # Check if routing key of the binding is the same
      if ($routing_key != undef) {
        exec { "rabbitmq_management_binding_${name}_routing_key":
          command => "${delete} && ${create_correct}",
          unless  => "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} --vhost=${vhost} list bindings source destination routing_key | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep '|${source}|${destination}|${routing_key}|'",
          require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_vhost_${vhost_name}"]],
        }
      }
    }
    'absent': {
      # Delete binding
      exec { "rabbitmq_management_binding_${name}":
        onlyif  => $find,
        command => $delete,
        require => [Package['coreutils'], Package['grep'], Exec['rabbitmq_management_admin_cli']],
      }
    }
    default: {
      fail('Unknown ensure: $ensure, must be present or absent')
    }
  }
}
