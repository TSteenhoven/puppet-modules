define rabbitmq::management_queue(
    Enum['present','absent']    $ensure     = present,
    Optional[String]            $vhost      = '/',
    Optional[Boolean]           $durable    = true
) {

    case $ensure {
        present: {
            /* Get durable value */
            if ($durable) {
                $durable_value = 'true'
            } else {
                $durable_value = 'false'
            }

            /* Create queue */
            exec { "rabbitmq_management_queue_${name}":
                command => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf declare queue --vhost=${vhost} name=${name} durable=${durable_value}",
                unless  => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf --format bash list queues | /usr/bin/grep ${name}",
                require => File['rabbitmq_management_admin_cli']
            }
        }
        absent: {
            /* Delete queue */
            exec { "rabbitmq_management_queue_${name}":
                onlyif => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf --format bash list queues | /usr/bin/grep ${name}",
                command => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf delete queue name=${name}",
            }
        }
        default: {
            fail('Unknown ensure: $ensure, must be present or absent')
        }
    }
}
