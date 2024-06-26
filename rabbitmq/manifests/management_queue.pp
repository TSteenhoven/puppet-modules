define rabbitmq::management_queue(
    Enum['present','absent']    $ensure     = present,
    Optional[String]            $vhost      = '/',
    Optional[Boolean]           $durable    = true,
    Optional[Data]              $arguments  = undef
) {

    /* Set create command */
    $create = "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf declare queue --vhost=${vhost} name=${name} durable=${durable_value}"
    if ($arguments == undef) {
        $arguments_json = ''
        $create_correct = $create
    } else {
        $arguments_json = stdlib::to_json($arguments)
        $create_correct = "${create} arguments='${arguments_json}'"
    }

    /* Set delete command */
    $delete = "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf delete queue name=${name}"

    case $ensure {
        present: {
            /* Get durable value */
            if ($durable) {
                $durable_value = 'true'
                $durable_ucfirstvalue = 'True'
            } else {
                $durable_value = 'false'
                $durable_ucfirstvalue = 'False'
            }

            /* Create queue */
            exec { "rabbitmq_management_queue_${name}":
                command => $create_correct,
                unless  => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf --format bash list queues | /usr/bin/grep ${name}",
                require => Exec['rabbitmq_management_admin_cli']
            }

            /* Check if durable of the exange is the same */
            exec { "rabbitmq_management_queue_${name}_durable":
                command => "${delete} && ${create_correct}",
                unless  => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf list queue name durable | /usr/bin/grep ${name} | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep '|${name}|${durable_ucfirstvalue}|'",
                require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_queue_${name}"]]
            }
        }
        absent: {
            /* Delete queue */
            exec { "rabbitmq_management_queue_${name}":
                onlyif => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf --format bash list queues | /usr/bin/grep ${name}",
                command => $delete,
                require => Exec['rabbitmq_management_admin_cli']
            }
        }
        default: {
            fail('Unknown ensure: $ensure, must be present or absent')
        }
    }
}
