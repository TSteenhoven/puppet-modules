class basic_settings::package_rabbitmq(
    Enum['list','822']  $deb_version,
    Boolean             $enable,
    String              $os_parent,
    String              $os_name
) {
    /* Reload source list */
    exec { 'package_rabbitmq_source_reload':
        command     => '/usr/bin/apt-get update',
        refreshonly => true
    }

    /* Check if we need newer format for APT */
    if ($deb_version == '822') {
        $file_erlang = '/etc/apt/sources.list.d/rabbitmq-erlang.sources'
        $file_server = '/etc/apt/sources.list.d/rabbitmq-server.sources'
    } else {
        $file_erlang = '/etc/apt/sources.list.d/rabbitmq-erlang.list'
        $file_server = '/etc/apt/sources.list.d/rabbitmq-server.list'
    }

    if ($enable) {
        /* Get source */
        if ($deb_version == '822') {
            $source_erlang  = "Types: deb\nURIs: https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/${os_parent}\nSuites: ${os_name}\nComponents: main\nSigned-By:/usr/share/keyrings/rabbitmq-erlang.gpg\n"
            $source_server  = "Types: deb\nURIs: https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/${os_parent}\nSuites: ${os_name}\nComponents: main\nSigned-By:/usr/share/keyrings/rabbitmq-server.gpg\n"
        } else {
            $source_erlang = "deb [signed-by=/usr/share/keyrings/rabbitmq-erlang.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/${os_parent} ${os_name} main\n"
            $source_server = "deb [signed-by=/usr/share/keyrings/rabbitmq-server.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/${os_parent} ${os_name} main\n"
        }

        /* Install Rabbitmq erlang repo */
        exec { 'package_rabbitmq_erlang_source':
            command     => "/usr/bin/printf \"${source_erlang}\" > ${file_erlang}; /usr/bin/curl -fsSL https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/gpg.E495BB49CC4BBE5B.key | gpg --dearmor | tee /usr/share/keyrings/rabbitmq-erlang.gpg >/dev/null; chmod 644 /usr/share/keyrings/rabbitmq-erlang.gpg",
            unless      => "[ -e ${file_erlang} ]",
            notify      => Exec['package_rabbitmq_source_reload'],
            require     => [Package['curl'], Package['gnupg']]
        }

        /* Install Rabbitmq server repo */
        exec { 'package_rabbitmq_server_source':
            command     => "/usr/bin/printf \"${source_server}\" >  ${file_server}; /usr/bin/curl -fsSL https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/gpg.9F4587F226208342.key | gpg --dearmor | tee /usr/share/keyrings/rabbitmq-server.gpg >/dev/null; chmod 644 /usr/share/keyrings/rabbitmq-server.gpg",
            unless      => "[ -e  ${file_server} ]",
            notify      => Exec['package_rabbitmq_source_reload'],
            require     => [Package['curl'], Package['gnupg']]
        }
    } else {
        /* Remove Rabbitmq erlang repo */
        exec { 'package_rabbitmq_erlang_source':
            command     => "/usr/bin/rm ${file_erlang}",
            onlyif      => "[ -e ${file_erlang} ]",
            notify      => Exec['package_rabbitmq_source_reload']
        }

        /* Remove Rabbitmq server repo */
        exec { 'package_rabbitmq_server_source':
            command     => "/usr/bin/rm  ${file_server}",
            onlyif      => "[ -e  ${file_server} ]",
            notify      => Exec['package_rabbitmq_source_reload']
        }
    }
}
