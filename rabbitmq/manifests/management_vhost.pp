define rabbitmq::management_vhost(
    Enum['present','absent']    $ensure     = present,
    Optional[String]            $type       = 'classic'
) {
    /* Get exec name */
    if ($name == '/') {
        $exec_name = 'default'
    } else {
        $exec_name = $vhost
    }

    case $ensure {
        present: {
            /* Check if vhost exists */
            exec { "rabbitmq_management_vhost_${exec_name}":
                command => "/usr/sbin/rabbitmqctl add_vhost ${name} --default-queue-type ${type}",
                unless  => "/usr/sbin/rabbitmqctl --quiet list_vhosts --no-table-headers name | /usr/bin/grep ${name}",
                require => [Package['grep'], Exec['rabbitmq_management_plugin']]
            }

            /* Check if type of the vhost is the same */
            exec { "rabbitmq_management_vhost_${exec_name}_type":
                command => "/usr/sbin/rabbitmqctl update_vhost_metadata ${name} --default-queue-type ${type}",
                unless  => "/usr/sbin/rabbitmqctl --quiet list_vhosts --no-table-headers name default_queue_type | /usr/bin/grep ${name} | /usr/bin/tr '[:blank:]' '|' | /usr/bin/grep '${name}|${type}'",
                require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_vhost_${name}"]]
            }
        }
        absent: {
            /* Delete vhost */
            exec { "rabbitmq_management_vhost_${name}":
                onlyif => "/usr/sbin/rabbitmqctl --quiet list_vhosts --no-table-headers name | /usr/bin/grep ${name}",
                command => "/usr/sbin/rabbitmqctl --quiet delete_vhost ${name}",
                require => [Package['grep'], Exec['rabbitmq_management_plugin']]
            }
        }
        default: {
            fail('Unknown ensure: $ensure, must be present or absent')
        }
    }
}
