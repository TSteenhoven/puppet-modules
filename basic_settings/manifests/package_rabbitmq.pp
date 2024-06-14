class basic_settings::package_rabbitmq(
    $enable,
    $os_parent,
    $os_name
) {
    /* Reload source list */
    exec { 'package_rabbitmq_source_list_reload':
        command     => 'apt-get update',
        refreshonly => true
    }

    /* Get distribution name */
    case $os_parent {
        'ubuntu': {
            case $os_name {
                'noble', 'lunar', 'jammy': {
                    $distribution = 'jammy'
                    $allow = true
                }
                default: {
                    $distribution = ''
                    $allow = false
                }
            }
        }
        'debian': {
            case $os_name {
                'buster', 'bullseye': {
                    $distribution = 'buster'
                    $allow = true
                }
                default: {
                    $distribution = ''
                    $allow = false
                }
            }
        }
        default: {
            $distribution = ''
            $allow = false
        }
    }

    if ($enable and $allow) {
        /* Install Rabbitmq erlang repo */
        exec { 'package_rabbitmq_erlang':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/rabbitmq-erlang.gpg] https://ppa1.novemberain.com/rabbitmq/rabbitmq-erlang/deb/ubuntu ${distribution} main\\ndeb [signed-by=/usr/share/keyrings/rabbitmq-erlang.gpg] https://ppa2.novemberain.com/rabbitmq/rabbitmq-erlang/deb/ubuntu jammy main\\n\" > /etc/apt/sources.list.d/rabbitmq-erlang.list; curl -s https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key | gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq-erlang.gpg >/dev/null",
            unless      => '[ -e /etc/apt/sources.list.d/rabbitmq-erlang.list ]',
            notify      => Exec['package_rabbitmq_source_list_reload'],
            require     => [Package['curl'], Package['gnupg']]
        }

        /* Install Rabbitmq server repo */
        exec { 'package_rabbitmq_server':
            command     => "printf \"deb [signed-by=/usr/share/keyrings/rabbitmq-server.gpg] https://ppa1.novemberain.com/rabbitmq/rabbitmq-server/deb/ubuntu ${distribution} main\\ndeb [signed-by=/usr/share/keyrings/rabbitmq-server.gpg] https://ppa2.novemberain.com/rabbitmq/rabbitmq-server/deb/ubuntu jammy main\\n\" > /etc/apt/sources.list.d/rabbitmq-server.list; curl -s https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key | gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq-server.gpg >/dev/null",
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
