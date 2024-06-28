define rabbitmq::management_exange(
    Enum['present','absent']    $ensure     = present,
    Optional[String]            $vhost      = '/',
    Optional[String]            $type       = 'direct'
) {

    /* Set commands */
    $find = "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} --format bash list exchanges | /usr/bin/grep ${name}"
    $delete = "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} delete exchange name=${name}"

    case $ensure {
        present: {
            /* Get vhost name */
            if ($vhost == '/') {
                $vhost_name = 'default'
            } else {
                $vhost_name = $vhost
            }

            /* Set create command */
            $create = "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} --vhost=${vhost} declare exchange name=${name} type=${type}"

            /* Create exange */
            exec { "rabbitmq_management_exange_${name}":
                command => $create,
                unless  => $find,
                require => [Package['grep'], Exec['rabbitmq_management_admin_cli'], Exec["rabbitmq_management_vhost_${vhost_name}"]]
            }

            /* Check if type of the exange is the same */
            exec { "rabbitmq_management_exange_${name}_type":
                command => "${delete} && ${create}",
                unless  => "/usr/sbin/rabbitmqadmin --config ${rabbitmq::management::admin_config_path} list exchanges name type | /usr/bin/grep ${name} | /usr/bin/tr -d '[:blank:]' | /usr/bin/grep '|${name}|${type}|'",
                require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_exange_${name}"]]
            }
        }
        absent: {
            /* Delete exange */
            exec { "rabbitmq_management_exange_${name}":
                onlyif => $find,
                command => $delete,
                require => [Package['grep'], Exec['rabbitmq_management_admin_cli']]
            }
        }
        default: {
            fail('Unknown ensure: $ensure, must be present or absent')
        }
    }
}
