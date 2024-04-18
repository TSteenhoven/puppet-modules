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
                '-a always,exit -F arch=b32 -F path=/etc/pam.d -F perm=wa -F key=pam',
                '-a always,exit -F arch=b64 -F path=/etc/pam.d -F perm=wa -F key=pam',
                '-a always,exit -F arch=b32 -F path=/etc/security/limits.conf -F perm=wa  -F key=pam',
                '-a always,exit -F arch=b64 -F path=/etc/security/limits.conf -F perm=wa  -F key=pam',
                '-a always,exit -F arch=b32 -F path=/etc/security/pam_env.conf -F perm=wa -F key=pam',
                '-a always,exit -F arch=b64 -F path=/etc/security/pam_env.conf -F perm=wa -F key=pam',
                '-a always,exit -F arch=b32 -F path=/etc/security/namespace.conf -F perm=wa -F key=pam',
                '-a always,exit -F arch=b64 -F path=/etc/security/namespace.conf -F perm=wa -F key=pam',
                '-a always,exit -F arch=b32 -F path=/etc/security/namespace.init -F perm=wa -F key=pam',
                '-a always,exit -F arch=b64 -F path=/etc/security/namespace.init -F perm=wa -F key=pam',
                '# Sudoers configuration',
                '-a always,exit -F arch=b32 -F path=/etc/sudoers -F perm=r -F auid!=unset -F key=sudoers',
                '-a always,exit -F arch=b64 -F path=/etc/sudoers -F perm=r -F auid!=unset -F key=sudoers',
                '-a always,exit -F arch=b32 -F path=/etc/sudoers.d -F perm=r -F auid!=unset -F key=sudoers',
                '-a always,exit -F arch=b64 -F path=/etc/sudoers.d -F perm=r -F auid!=unset -F key=sudoers',
                '-a always,exit -F arch=b32 -F path=/etc/sudoers -F perm=wa -F key=sudoers',
                '-a always,exit -F arch=b64 -F path=/etc/sudoers -F perm=wa -F key=sudoers',
                '-a always,exit -F arch=b32 -F path=/etc/sudoers.d -F perm=wa -F key=sudoers',
                '-a always,exit -F arch=b64 -F path=/etc/sudoers.d -F perm=wa -F key=sudoers',
            ],
            rule_suspicious_packages    => $suspicious_packages
        }
    }
}
