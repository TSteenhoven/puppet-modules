define rabbitmq::management_user_permissions(
    $user,
    $vhost       = '/',
    $configure   = '.*',
    $write       = '.*',
    $read        = '.*'
) {
    /* Get exec name */
    if ($vhost == '/') {
        $exec_name = 'default'
    } else {
        $exec_name = $vhost
    }

    /* Set permissions */
    exec { "rabbitmq_management_user_${user}_permissions_${exec_name}":
        command => "/usr/sbin/rabbitmqctl --quiet set_permissions -p ${vhost} ${user} '${configure}' '${write}' '${read}'",
        unless  => "/usr/sbin/rabbitmqctl --quiet list_user_permissions --no-table-headers ${user} | /usr/bin/tr -d '\t' | /usr/bin/grep '${vhost}${configure}${write}${read}'",
        require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_user_${user}"]]
    }
}
