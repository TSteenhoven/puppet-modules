
class basic_settings::package_sury(
    $deb_version,
    $enable,
    $os_parent,
    $os_name
) {
    /* Reload source list */
    exec { 'package_sury_source_reload':
        command     => '/usr/bin/apt-get update',
        refreshonly => true
    }

    /* Check if we need newer format for APT */
    if ($deb_version == '822') {
        $file = '/etc/apt/sources.list.d/sury_php.sources'
    } else {
        $file = '/etc/apt/sources.list.d/sury_php.list'
    }

    /* Check if enabled */
    if ($enable) {
        /* Get variables */
        case $os_parent {
            'ubuntu': {
                $url = 'https://ppa.launchpadcontent.net/ondrej/php/ubuntu'
                $key = '/usr/share/keyrings/sury.gpg'
            }
            default: {
                $url = 'https://packages.sury.org/php'
                $key = '/usr/share/keyrings/deb.sury.org-php.gpg'
            }
        }

        /* Get source */
        if ($deb_version == '822') {
            $source  = "Types: deb\nURIs: ${url}\nSuites: ${os_name}\nComponents: main\nSigned-By:${key}\n"
        } else {
            $source = "deb [signed-by=${key}] ${url} ${os_name} main\n"
        }
    } else {
        $url = undef
        $key = undef
        $source = undef
    }

    /* Check if enabled */
    if ($enable) {
        /* Add sury PHP repo */
        case $os_parent {
            'ubuntu': {
                exec { 'source_sury_php':
                    command     => "/usr/bin/printf \"${source}\" > ${file}; curl -s https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14AA40EC0831756756D7F66C4F4EA0AAE5267A6C | gpg --dearmor | tee ${key} >/dev/null; chmod 644 ${key}",
                    unless      => "[ -e ${file} ]",
                    notify      => Exec['package_sury_source_reload'],
                    require     => [Package['curl'], Package['gnupg']]
                }
            }
            default: {
                exec { 'source_sury_php':
                    command     => "curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb; dpkg -i /tmp/debsuryorg-archive-keyring.deb; printf \"${source}\" > ${file}",
                    unless      => "[ -e ${file} ]",
                    notify      => Exec['package_sury_source_reload'],
                    require     => [Package['curl'], Package['gnupg']]
                }
            }
        }
    } else {
        /* Remove sury php repo */
        exec { 'source_sury_php':
            command     => "/usr/bin/rm ${file}",
            onlyif      => "[ -e ${file} ]",
            notify      => Exec['package_sury_source_reload']
        }
    }
}
