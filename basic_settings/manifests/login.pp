class basic_settings::login(
    $mail_to                = 'root',
    $server_fdqn            = $fdqn,
    $sudoers_dir_enable     = false,
    $getty_enable           = false
) {
    /* Remove unnecessary packages */
    package { ['session-migration', 'xdg-user-dirs']:
        ensure  => purged
    }

    /* Install packages */
    package { ['bash-completion', 'sudo', 'libpam-modules']:
        ensure  => installed
    }

    /* Create group wheel */
    group { 'wheel':
        system => true
    }

    /* Create list of packages that is suspicious */
    $suspicious_packages = ['/usr/bin/sudo', '/usr/sbin/pam-auth-update'];

    /* Run command when PAM file is changed */
    exec { 'login_pam_auth_update':
        command         => '/usr/sbin/pam-auth-update --package',
        refreshonly     => true,
        require         => Package['systemd']
    }

    /* Setup pam common-session file */
    file { '/usr/share/pam-configs/custom':
        ensure  => file,
        mode    => '0664',
        owner   => 'root',
        group   => 'root',
        content => template('basic_settings/login/pam/custom'),
        notify  => Exec['login_pam_auth_update'],
    }

    /* Setup su pam config file */
    file { '/etc/pam.d/su':
        ensure  => file,
        mode    => '0664',
        owner   => 'root',
        group   => 'root',
        content => template('basic_settings/login/pam/su')
    }

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
    if ($operatingsystem == 'Ubuntu') {
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

    # Create profile trigger */
    file { '/etc/profile.d/99-login-notify.sh':
        ensure  => file,
        content => template('basic_settings/login/login-notify.sh'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
    }

    /* Ensure that getty is stopped or running */
    if ($getty_enable) {
        service { 'getty@tty*':
            ensure      => stopped,
            enable      => false
        }
    } else {
        service { 'getty@tty*':
            ensure      => running,
            enable      => true
        }
    }

    /* Check if we have systemd */
    if (defined(Package['systemd'])) {
        /* Reload systemd deamon */
        exec { 'login_systemd_daemon_reload':
            command         => '/usr/bin/systemctl daemon-reload',
            refreshonly     => true,
            require         => Package['systemd']
        }

        /* Create drop in for getty service */
        basic_settings::systemd_drop_in { 'getty_settings':
            target_unit     => 'getty@.service',
            unit            => {
                'ConditionPathExists' => '/dev/%I'
            },
            daemon_reload   => 'login_systemd_daemon_reload'
        }
    }

    /* Setup audit rules */
    if (defined(Package['auditd'])) {
        basic_settings::security_audit { 'login':
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
