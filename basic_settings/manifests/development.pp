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
        $suspicious_packages = ['/usr/bin/gcc', '/usr/bin/git']
        package { 'gcc':
            ensure  => installed,
        }
    } else {
        $suspicious_packages = ['/usr/bin/gcc', "/usr/bin/gcc-${gcc_version}", '/usr/bin/git']
        package { ['gcc', "gcc-${gcc_version}"]:
            ensure  => installed
        }
    }

    /* Install packages */
    package { 'git':
        ensure          => installed,
        install_options => $install_options
    }

    /* Setup audit */
    if (defined(Package['auditd'])) {
        basic_settings::security_audit { 'development':
            rule_suspicious_packages => $suspicious_packages
        }
    }
}
