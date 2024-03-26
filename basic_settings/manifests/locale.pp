class basic_settings::locale(
    $enable         = false,
    $docs_enable    = false
) {

    /* Check if packages are needed */
    if ($enable) {
        package { 'locales':
            ensure  => installed
        }
    } else {
        package { 'locales':
            ensure  => purged
        }
    }

    /* Check if docs is needed */
    if ($enable and $docs_enable)  {
        package { ['manpages', 'manpages-dev', 'man-db']:
            ensure  => installed
        }
    } else {
        package { ['manpages', 'manpages-dev', 'man-db']:
            ensure  => purged
        }
    }
}
