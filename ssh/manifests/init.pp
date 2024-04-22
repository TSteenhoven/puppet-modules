
class ssh(
    $allow_users                    = [],
    $banner_text                    = "WARNING! You are entering a managed service!\nThis service should only be accessed by authorized users and must have a valid reason. All activity on this system is recorded and forwarded.\nUnauthorized access is fully investigated and reported to law enforcement authorities.",
    $password_authentication_users  = [],
    $permit_root_login              = false,
    $port                           = 22
) {

    /* Required packages for SSHD */
    package { ['openssh-server', 'openssh-client']:
        ensure => installed
    }

    /* Convert array to string */
    $str_allow_users = join($allow_users, ' ')
    $str_password_authentication_users = join($password_authentication_users, ',')

    /* Create SSHD directory config */
    file { '/etc/ssh/sshd_config.d':
        ensure  => directory,
        mode    => '0600',
        owner   => 'root',
        group   => 'root',
        require => Package['openssh-server']
    }

    /* Banner */
    file { '/etc/issue.net':
        ensure  => file,
        mode    => '0644',
        content => "${banner_text}\n"
    }

    /* Create SSHD custom config */
    file { '/etc/ssh/sshd_config.d/99-custom.conf':
        ensure  => file,
        mode    => '0600',
        owner   => 'root',
        group   => 'root',
        content => template('ssh/custom.conf'),
        require => File['/etc/ssh/sshd_config.d']
    }

    /* Ensure that ssh is always running */
    service { 'ssh':
        ensure      => running,
        enable      => true,
        require     => File['/etc/ssh/sshd_config.d/99-custom.conf'],
        subscribe   => File['/etc/ssh/sshd_config.d/99-custom.conf']
    }

    /* Set SSH settings */
    if (defined(Package['systemd'])) {
        /* Reload systemd deamon */
        exec { 'ssh_systemd_daemon_reload':
            command     => 'systemctl daemon-reload',
            refreshonly => true,
            require     => Package['systemd']
        }

        /* Create drop in for ssh service */
        basic_settings::systemd_drop_in { 'ssh_settings':
            ensure          => absent,
            target_unit     => 'ssh.service',
            daemon_reload   => 'ssh_systemd_daemon_reload',
            require         => Package['nginx']
        }
    }

    if (defined(Package['auditd'])) {
        basic_settings::security_audit { 'ssh':
            rules => [
                '-a always,exit -F arch=b32 -F path=/etc/ssh/sshd_config -F perm=r -F auid!=unset -F key=sshd',
                '-a always,exit -F arch=b64 -F path=/etc/ssh/sshd_config -F perm=r -F auid!=unset -F key=sshd',
                '-a always,exit -F arch=b32 -F path=/etc/ssh/sshd_config.d -F perm=r -F auid!=unset -F key=sshd',
                '-a always,exit -F arch=b64 -F path=/etc/ssh/sshd_config.d -F perm=r -F auid!=unset -F key=sshd',
                '-a always,exit -F arch=b32 -F path=/etc/ssh/sshd_config -F perm=wa -F key=sshd',
                '-a always,exit -F arch=b64 -F path=/etc/ssh/sshd_config -F perm=wa -F key=sshd',
                '-a always,exit -F arch=b32 -F path=/etc/ssh/sshd_config.d -F perm=wa -F key=sshd',
                '-a always,exit -F arch=b64 -F path=/etc/ssh/sshd_config.d -F perm=wa -F key=sshd'
            ],
            rule_suspicious_packages => [
                '/usr/bin/ssh'
            ]
        }
    }
}
