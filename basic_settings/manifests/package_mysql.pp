class basic_settings::package_mysql(
    $enable,
    $os_parent,
    $os_name,
    $version = '8.0'
) {
    /* Reload source list */
    exec { 'package_mysql_source_list_reload':
        command     => 'apt-get update',
        refreshonly => true
    }

    if ($enable) {
        /* Get source name */
        case $version {
            '8.0': {
                $key = 'mysql-8.key'
            }
            default: {
                $key = 'mysql-7.key'
            }
        }

        /* Create MySQL key */
        file { 'package_mysql_key':
            ensure  => file,
            path    => '/usr/share/keyrings/mysql.key',
            source  => "puppet:///modules/basic_settings/mysql/${key}",
            owner   => 'root',
            group   => 'root',
            mode    => '0644'
        }

        /* Set source */
        exec { 'package_mysql_source':
            command     => "/usr/bin/printf \"deb [signed-by=/usr/share/keyrings/mysql.gpg] http://repo.mysql.com/apt/${os_parent} ${os_name} mysql-${version}\\n\" > /etc/apt/sources.list.d/mysql.list; cat /usr/share/keyrings/mysql.key | gpg --dearmor | tee /usr/share/keyrings/mysql.gpg >/dev/null; chmod 644 /usr/share/keyrings/mysql.gpg",
            unless      => '[ -e /etc/apt/sources.list.d/mysql.list ]',
            notify      => Exec['package_mysql_source_list_reload'],
            require     => [Package['curl'], Package['gnupg'], File['package_mysql_key']]
        }
    } else {
        /* Remove mysql repo */
        exec { 'package_mysql_source':
            command     => '/usr/bin/rm /etc/apt/sources.list.d/mysql.list',
            onlyif      => '[ -e /etc/apt/sources.list.d/mysql.list ]',
            notify      => Exec['package_mysql_source_list_reload']
        }
    }
}
