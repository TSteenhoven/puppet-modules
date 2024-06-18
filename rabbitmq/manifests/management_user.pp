define rabbitmq::management_user(
    $ensure     = present,
    $password   = undef,
    $tags       = ['administrator']
) {
    /* Run user */
    case $ensure {
        present: {
            /* When password is not given; Create random passowrd */
            if ($password == undef) {
                if (defined(Resource['basic_settings::login_user', $name])) {
                    $user_home = getparam(Resource['basic_settings::login_user', $name], 'home')
                    $user_addd = "bash -c 'TMPPASS=`/usr/bin/pwgen -s 26 1`; echo \$TMPPASS > ${user_home}/.rabbitmq.password; chown ${name}:${name} ${user_home}/.rabbitmq.password; chmod 600 ${user_home}/.rabbitmq.password; echo \$TMPPASS | /usr/sbin/rabbitmqctl add_user ${name}'"
                } else {
                    fail("User ${name} not present")
                }
            } else {
                $user_addd = "/usr/sbin/rabbitmqctl add_user ${name} ${password}"
            }

            /* Create user */
            exec { "rabbitmq_management_user_${name}":
                command => $user_addd,
                unless  => "/usr/sbin/rabbitmqctl list_user_limits --user ${name}",
                require => Exec['rabbitmq_management_plugin']
            }

            /* Set tags */
            $user_tags_join = join($tags, ' ')
            $user_tags_search = join($tags, ' | grep ')
            exec { "rabbitmq_management_user_${name}_tags":
                command => "/usr/sbin/rabbitmqctl --quiet set_user_tags ${name} ${user_tags_join}",
                unless  => "/usr/sbin/rabbitmqctl --quiet list_users --no-table-headers | grep ${name} | cut -f2 | grep ${user_tags_search}",
                require => Exec["rabbitmq_management_user_${name}"]
            }
        }
        absent: {

        }
        default: {
            fail('Unknown ensure: $ensure, must be present or absent')
        }
    }
}