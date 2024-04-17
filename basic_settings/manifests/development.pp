class basic_settings::development(
    $gcc_version        = undef,
    $install_options    = undef
) {

    /* Install default development packages */
    package { ['build-essential', 'python-is-python3', 'python3', 'ruby', 'screen']:
        ensure  => installed
    }

    /* Set default rules */
    $default_rules = ['/usr/bin/gcc', '/usr/bin/git', '/usr/bin/gmake', '/usr/bin/make']

    /* Install gcc packages */
    if ($gcc_version == undef) {
        package { 'gcc':
            ensure  => installed,
        }

        /* Create list of packages that is suspicious */
        $suspicious_packages = $default_rules
    } else {
        package { ['gcc', "gcc-${gcc_version}"]:
            ensure  => installed
        }

        /* Create list of packages that is suspicious */
        $suspicious_packages = flatten($default_rules, ["/usr/bin/gcc-${gcc_version}"])
    }

    /* Install packages */
    package { 'git':
        ensure          => installed,
        install_options => $install_options
    }

    /* Setup audit rules */
    if (defined(Package['auditd'])) {
        basic_settings::security_audit { 'development':
            rule_suspicious_packages => $suspicious_packages
        }
    }
}
