define rabbitmq::management_exange(
    Enum['present','absent']    $ensure     = present,
    Optional[String]            $vhost      = '/',
    Optional[String]            $type       = 'direct'
) {

    /* Set delete command */
    $delete = "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf delete exchange name=${name}"

    case $ensure {
        present: {
            /* Set create command */
            $create = "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf declare exchange --vhost=${vhost} name=${name} type=${type}"

            /* Create exange */
            exec { "rabbitmq_management_exange_${name}":
                command => $create,
                unless  => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf --format bash list exchanges | /usr/bin/grep ${name}",
                require => Exec['rabbitmq_management_admin_cli']
            }

            /* Check if type of the exange is the same */
            exec { "rabbitmq_management_exange_${name}_type":
                command => "${delete} && ${create}",
                unless  => "/usr/sbin/rabbitmqadmin --config /etc/rabbitmq/rabbitmqadmin.conf list exchanges name type | /usr/bin/grep ${name} | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep '|${name}|${type}|'",
                require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_exange_${name}"]]
            }
        }
        absent: {
            /* Delete exange */
            exec { "rabbitmq_management_exange_${name}":
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
