class basic_settings::login(
    $mail_to                = 'root',
    $server_fdqn            = $fdqn,
    $sudoers_dir_enable     = false
) {
    /* Remove unnecessary packages */
    package { ['session-migration', 'xdg-user-dirs']:
        ensure  => purged
    }

    /* Install packages */
    package { ['bash-completion', 'sudo', 'libpam-modules']:
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
        content => template('basic_settings/login/sudoers')
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

    /* Check if OS is Ubuntu */
    if ($os_parent == 'ubuntu') {
        /* Install packages */
        package { 'update-motd':
            ensure  => installed
        }

        /* Disable motd news */
        file { '/etc/default/motd-news':
            ensure  => file,
            mode    => '0644',
            content => "ENABLED=0\n"
        }

        /* Ensure that motd-news is stopped */
        service { 'motd-news.timer':
            ensure      => stopped,
            enable      => false,
            require     => File['/etc/default/motd-news'],
            subscribe   => File['/etc/default/motd-news']
        }
    }

    # Create motd trigger */
    file { '/etc/update-motd.d/92-login-notify':
        ensure  => file,
        content => template('basic_settings/login/login-notify'),
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
    }

    /* Setup audit rules */
    if (defined(Package['auditd'])) {
        basic_settings::security_audit { 'user':
            rules                       => [
                '# User configuration',
                '-a always,exit -F arch=b32 -F path=/etc/security/limits.conf -F perm=wa  -F key=limits',
                '-a always,exit -F arch=b64 -F path=/etc/security/limits.conf -F perm=wa  -F key=limits',
                '-a always,exit -F arch=b32 -F path=/etc/security/namespace.conf -F perm=wa -F key=namespace',
                '-a always,exit -F arch=b64 -F path=/etc/security/namespace.conf -F perm=wa -F key=namespace',
                '-a always,exit -F arch=b32 -F path=/etc/security/namespace.init -F perm=wa -F key=namespace',
                '-a always,exit -F arch=b64 -F path=/etc/security/namespace.init -F perm=wa -F key=namespace',
                '# PAM configuration',
                '-a always,exit -F arch=b32 -F path=/etc/pam.d -F perm=wa -F key=pam',
                '-a always,exit -F arch=b64 -F path=/etc/pam.d -F perm=wa -F key=pam',
                '-a always,exit -F arch=b32 -F path=/etc/security/pam_env.conf -F perm=wa -F key=pam',
                '-a always,exit -F arch=b64 -F path=/etc/security/pam_env.conf -F perm=wa -F key=pam',
                '# Sudoers configuration',
                '-a always,exit -F arch=b32 -F path=/etc/sudoers -F perm=r -F auid!=unset -F key=sudoers',
                '-a always,exit -F arch=b64 -F path=/etc/sudoers -F perm=r -F auid!=unset -F key=sudoers',
                '-a always,exit -F arch=b32 -F path=/etc/sudoers.d -F perm=r -F auid!=unset -F key=sudoers',
                '-a always,exit -F arch=b64 -F path=/etc/sudoers.d -F perm=r -F auid!=unset -F key=sudoers',
                '-a always,exit -F arch=b32 -F path=/etc/sudoers -F perm=wa -F key=sudoers',
                '-a always,exit -F arch=b64 -F path=/etc/sudoers -F perm=wa -F key=sudoers',
                '-a always,exit -F arch=b32 -F path=/etc/sudoers.d -F perm=wa -F key=sudoers',
                '-a always,exit -F arch=b64 -F path=/etc/sudoers.d -F perm=wa -F key=sudoers'
            ],
            rule_suspicious_packages    => $suspicious_packages
        }
    }
}
