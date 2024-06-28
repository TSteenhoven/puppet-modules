define rabbitmq::management_binding(
    String                      $source,
    String                      $destination,
    String                      $routing_key,
    Enum['present','absent']    $ensure         = present,
    Optional[String]            $vhost          = '/'
) {

    /* Set delete command */
    $delete = "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf delete binding properties_key=${name}"

    case $ensure {
        present: {
            /* Get vhost name */
            if ($vhost == '/') {
                $vhost_name = 'default'
            } else {
                $vhost_name = $vhost
            }

            /* Set create command */
            $create = "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf --vhost=${vhost} declare binding properties_key=${name} source=${source} destination=${destination} routing_key=${routing_key}"

            /* Create binding */
            exec { "rabbitmq_management_binding_${name}":
                command => $create,
                unless  => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf --vhost=${vhost} list bindings properties_keys | /usr/bin/grep ${name}",
                require => [Exec['rabbitmq_management_admin_cli'], Exec["rabbitmq_management_vhost_${vhost_name}"]]
            }

            /* Check if source of the binding is the same */
            exec { "rabbitmq_management_binding_${name}_source":
                command => "${delete} && ${create}",
                unless  => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf list bindings properties_keys source | /usr/bin/grep ${name} | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep '|${name}|${source}|'",
                require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_vhost_${vhost_name}"]]
            }

            /* Check if destination of the binding is the same */
            exec { "rabbitmq_management_binding_${name}_destination":
                command => "${delete} && ${create}",
                unless  => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf list bindings properties_keys destination | /usr/bin/grep ${name} | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep '|${name}|${destination}|'",
                require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_vhost_${vhost_name}"]]
            }

            /* Check if routing key of the binding is the same */
            exec { "rabbitmq_management_binding_${name}_routing_key":
                command => "${delete} && ${create}",
                unless  => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf list bindings properties_keys routing_key | /usr/bin/grep ${name} | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep '|${name}|${routing_key}|'",
                require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_vhost_${vhost_name}"]]
            }
        }
        absent: {
            /* Delete binding */
            exec { "rabbitmq_management_binding_${name}":
                onlyif => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf --format bash list exchanges | /usr/bin/grep ${name}",
                command => $delete,
                require => Exec['rabbitmq_management_admin_cli']
            }
        }
        default: {
            fail('Unknown ensure: $ensure, must be present or absent')
        }
    }
}
