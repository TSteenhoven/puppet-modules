class basic_settings::locale(
    Optional[Boolean]   $enable         = false,
    Optional[String]    $dictionary     = 'american',
    Optional[Boolean]   $docs_enable    = false
) {

    /* Check if packages are needed */
    if ($enable) {
        package { ['dictionaries-common', 'locales', "w${dictionary}"]:
            ensure  => installed
        }

        /* Remove default locale file */
        file { '/etc/default/locale':
            ensure  => absent
        }
    } else {
        /* Remove packages */
        package { ['dictionaries-common', 'locales', 'wamerican', 'wbritish']:
            ensure  => purged
        }

        /* Install default locale file */
        file { '/etc/default/locale':
            ensure  => file,
            mode    => '0644',
            content => "LANG=C.UTF-8\n"
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
