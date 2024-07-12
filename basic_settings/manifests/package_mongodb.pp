class basic_settings::package_mongodb(
    $deb_version,
    $enable,
    $os_parent,
    $os_name,
    $version = '4.4'
) {
    /* Reload source list */
    exec { 'package_mongodb_source_reload':
        command     => '/usr/bin/apt-get update',
        refreshonly => true
    }

    /* Check if we need newer format for APT */
    if ($deb_version == '822') {
        $file = '/etc/apt/sources.list.d/mongodb.sources'
    } else {
        $file = '/etc/apt/sources.list.d/mongodb.list'
    }

    if ($enable) {
        /* Get source */
        if ($deb_version == '822') {
            $source  = "Types: deb\nURIs: https://repo.mongodb.org/apt/${os_parent}\nSuites: ${os_name}/mongodb-org/${version}\nComponents: main\nSigned-By:/usr/share/keyrings/mongodb.gpg\n"
        } else {
            $source = "deb [signed-by=/usr/share/keyrings/mongodb.gpg] https://repo.mongodb.org/apt/${os_parent} ${os_name}/mongodb-org/${version} main\n"
        }

        /* Install mongodb repo */
        exec { 'package_mongodb_source':
            command     => "/usr/bin/printf \"${source}\" > ${file}; /usr/bin/curl -fsSL https://pgp.mongodb.com/server-${version}.asc | gpg --dearmor | tee /usr/share/keyrings/mongodb.gpg >/dev/null; chmod 644 /usr/share/keyrings/mongodb.gpg",
            unless      => "[ -e ${file} ]",
            notify      => Exec['package_mongodb_source_reload'],
            require     => [Package['curl'], Package['gnupg']]
        }

        /* Install mongodb-org-server package */
        package { 'mongodb-org-server':
            ensure  => installed,
            require => Exec['package_mongodb_source']
        }
    } else {
        /* Remove mongodb-org-server package */
        package { 'mongodb-org-server':
            ensure  => purged
        }

        /* Remove mongodb repo */
        exec { 'package_mongodb_source':
            command     => "/usr/bin/rm ${file}",
            onlyif      => "[ -e ${file} ]",
            notify      => Exec['package_mongodb_source_reload'],
            require     => Package['mongodb-org-server']
        }
    }
}
