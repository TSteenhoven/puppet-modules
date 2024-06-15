class basic_settings::package::rabbitmq(
    $enable,
    $os_parent,
    $os_name
) {
    /* Reload source list */
    exec { 'package_rabbitmq_source_list_reload':
        command     => 'apt-get update',
        refreshonly => true
    }

    if ($enable) {
        /* Install Rabbitmq erlang repo */
        exec { 'package_rabbitmq_erlang':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/rabbitmq-erlang.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/${os_parent} ${os_name} main\\n\" > /etc/apt/sources.list.d/rabbitmq-erlang.list; curl -s https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/gpg.E495BB49CC4BBE5B.key | gpg --dearmor | tee /usr/share/keyrings/rabbitmq-erlang.gpg >/dev/null; chmod 644 /usr/share/keyrings/rabbitmq-erlang.gpg",
            unless      => '[ -e /etc/apt/sources.list.d/rabbitmq-erlang.list ]',
            notify      => Exec['package_rabbitmq_source_list_reload'],
            require     => [Package['curl'], Package['gnupg']]
        }

        /* Install Rabbitmq server repo */
        exec { 'package_rabbitmq_server':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/rabbitmq-server.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/${os_parent} ${os_name} main\\n\" > /etc/apt/sources.list.d/rabbitmq-server.list; curl -s https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/gpg.9F4587F226208342.key | gpg --dearmor | tee /usr/share/keyrings/rabbitmq-server.gpg >/dev/null; chmod 644 /usr/share/keyrings/rabbitmq-server.gpg",
            unless      => '[ -e /etc/apt/sources.list.d/rabbitmq-server.list ]',
            notify      => Exec['package_rabbitmq_source_list_reload'],
            require     => [Package['curl'], Package['gnupg']]
        }
    } else {
        /* Remove Rabbitmq erlang repo */
        exec { 'package_rabbitmq_erlang':
            command     => 'rm /etc/apt/sources.list.d/rabbitmq-erlang.list',
            onlyif      => '[ -e /etc/apt/sources.list.d/rabbitmq-erlang.list ]',
            notify      => Exec['package_rabbitmq_source_list_reload']
        }

        /* Remove Rabbitmq server repo */
        exec { 'package_rabbitmq_server':
            command     => 'rm /etc/apt/sources.list.d/rabbitmq-server.list',
            onlyif      => '[ -e /etc/apt/sources.list.d/rabbitmq-server.list ]',
            notify      => Exec['package_rabbitmq_source_list_reload']
        }
    }
}
