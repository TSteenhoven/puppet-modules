define rabbitmq::management_queue(
    Enum['present','absent']    $ensure     = present,
    Optional[Data]              $arguments  = undef,
    Optional[Boolean]           $durable    = true,
    Optional[String]            $type       = undef,
    Optional[String]            $vhost      = '/'
) {

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

            /* Set create command */
            $create = "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf --vhost=${vhost} declare queue name=${name} durable=${durable_value}"

            /* Set type */
            if ($type == undef) {
                $arguments_correct = $arguments
            } elsif ($arguments == undef) {
                $arguments_correct = { 'x-queue-type' => $type }
            } else {
                $arguments_correct = stdlib::merge({ 'x-queue-type' => $type }, $arguments)
            }

            /* Check if arguments is not given */
            if ($arguments_correct == undef) {
                $arguments_json = '{}'
                $create_correct = $create
            } else {
                $arguments_array = sort(Array($arguments_correct)) # Convert back to array for sorting
                $arguments_json = stdlib::to_json(Hash($arguments_array))
                $create_correct = "${create} arguments='${arguments_json}'"
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
                unless  => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf list queues name durable | /usr/bin/grep ${name} | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep '|${name}|${durable_ucfirstvalue}|'",
                require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_queue_${name}"]]
            }

            /* Check if arguments of the exange is the same */
            exec { "rabbitmq_management_queue_${name}_arguments":
                command => "${delete} && ${create_correct}",
                unless  => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf --format raw_json list queues name arguments | sed 's/},{/'\\},\\\n{'/g' | /usr/bin/grep grep '\"name\":\"${name}\"' | /usr/bin/grep '{\"arguments\":${arguments_json},\"name\":\"${name}\"}'",
                require => [Package['coreutils'], Package['grep'], Package['sed'], Exec["rabbitmq_management_queue_${name}"]]
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
