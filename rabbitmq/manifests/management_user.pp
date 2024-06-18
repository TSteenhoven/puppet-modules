define rabbitmq::management_user(
    $ensure,
    $password = undef,
    $tags = ['administrator']
) {
    /* Run user */
    case $ensure {
        present: {
            /* When password is not given; Create random passowrd */
            if ($password == undef) {
                if (defined(User[$title])) {
                    $user_addd = "TMPPASS=`/usr/bin/pwgen -s 26 1`; echo \$TMPPASS > /home/${title}/.rabbitmq.password; chown ${title}:${title} /home/${title}/.rabbitmq.password; chmod 600 /home/${title}/.rabbitmq.password; echo \$TMPPASS | /usr/sbin/rabbitmqctl add_user ${title}"
                } else {
                    fail('User not present')
                }
            } else {
                $user_addd = "/usr/sbin/rabbitmqctl add_user ${title} ${password}"
            }

            /* Create user */
            exec { "rabbitmq_management_user_${title}":
                command => $user_addd,
                unless  => "/usr/sbin/rabbitmqctl list_user_limits --user ${title}",
                require => Exec['rabbitmq_management_plugin']
            }

            /* Set tags */
            $user_tags_join = join($tags, ' ')
            $user_tags_search = join($tags, ' | grep ')
            exec { "rabbitmq_management_user_${title}_tags":
                command => "/usr/sbin/rabbitmqctl --quiet set_user_tags ${title} ${user_tags_join}",
                unless  => "/usr/sbin/rabbitmqctl --quiet list_users --no-table-headers | grep ${title} | cut -f2 | grep ${user_tags_search}",
                require => Exec["rabbitmq_management_user_${title}"]
            }
        }
        absent: {

        }
        default: {
            fail('Unknown ensure: $ensure, must be present or absent')
        }
    }
}
