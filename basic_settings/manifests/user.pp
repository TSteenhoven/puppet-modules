class basic_settings::user(
    $sudoers_dir_enable = false
) {
    /* Remove unnecessary packages */
    package { ['session-migration', 'xdg-user-dirs']:
        ensure  => purged
    }

    /* Install packages */
    package { ['bash-completion', 'libpam-modules', 'sudo']:
        ensure  => installed
    }

    /* Create list of packages that is suspicious */
    $suspicious_packages = ['/usr/bin/sudo'];

    /* Setup sudoers config file */
    file { '/etc/sudoers':
        ensure  => file,
        mode    => '0440',
        owner   => 'root',
        group   => 'root',
        content => template('basic_settings/user/sudoers')
    }

    /* Setup sudoers dir */
    if ($sudoers_dir_enable) {
        file { '/etc/sudoers.d':
            ensure  => directory,
            purge   => true,
            recurse => true,
            force   => true,
        }
    }

    /* Setup audit rules */
    if (defined(Package['auditd'])) {
        basic_settings::security_audit { 'user':
            rules                       => [
                '# PAM configuration',
                '-w /etc/pam.d -p wa -k pam',
                '-w /etc/security/limits.conf -p wa  -k pam',
                '-w /etc/security/pam_env.conf -p wa -k pam',
                '-w /etc/security/namespace.conf -p wa -k pam',
                '-w /etc/security/namespace.init -p wa -k pam',
                '# Sudoers configuration',
                '-w /etc/sudoers -p r -F auid!=unset -k sudoers',
                '-w /etc/sudoers.d -p r -F auid!=unset -k sudoers',
                '-w /etc/sudoers -p wa -k sudoers',
                '-w /etc/sudoers.d -p wa -k sudoers',
            ],
            rule_suspicious_packages    => $suspicious_packages
        }
    }
}
