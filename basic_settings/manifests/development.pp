class basic_settings::development(
    $gcc_version        = undef,
    $install_options    = undef
) {

    /* Install default development packages */
    package { 'build-essential':
        ensure  => installed
    }

    /* Install gcc packages */
    if ($gcc_version == undef) {
        package { 'gcc':
            ensure  => installed,
        }
    } else {
        package { ['gcc', "gcc-${gcc_version}"]:
            ensure  => installed
        }
    }

    /* Install packages */
    package { 'git':
        ensure          => installed,
        install_options => $install_options
    }
}
