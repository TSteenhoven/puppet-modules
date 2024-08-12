
class ssh(
    Optional[Array]     $allow_users                    = [],
    Optional[String]    $banner_text                    = "WARNING: You are entering a managed server!\nThis server should only be accessed by authorized users and must have a valid reason. All activity on this system is recorded and forwarded.\nUnauthorized access will be fully investigated and reported to law enforcement authorities.",
    Optional[Integer]   $idle_timeout                   = 15,
    Optional[Array]     $password_authentication_users  = [],
    Optional[Boolean]   $permit_root_login              = false,
    Optional[Integer]   $port                           = 22,
    Optional[Integer]   $port_alternative               = undef,
    Optional[Array]     $port_alternative_allow_users   = undef
) {

    /* Required packages for SSHD */
    package { ['openssh-server', 'openssh-client']:
        ensure => installed
    }

    /* Convert array to string */
    $str_allow_users = join($allow_users, ' ')
    $str_password_authentication_users = join($password_authentication_users, ',')

    /* Check if different list is given for alternative port */
    if ($port_alternative_allow_users != undef) {
        $str_port_alternative_allow_users = join($port_alternative_allow_users, ' ')
    } else {
        $str_port_alternative_allow_users = $str_allow_users
    }

    /* Check if SSH used socket */
    if (defined(Package['systemd'])) {
        /* Get OS name */
        case $::os['name'] {
            'Ubuntu': {
                /* Get OS name */
                case $::os['release']['major'] {
                    '23.04', '24.04': {
                        $systemd_socket = true
                    }
                    default: {
                        $systemd_socket = false
                    }
                }
            }
            default: {
                $systemd_socket = false
            }
        }
    } else {
        $systemd_socket = false
    }

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
        content => "${banner_text}\n\n"
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

    /* Check if we have systemd socket */
    if ($systemd_socket) {
        /* Reload systemd deamon */
        exec { 'ssh_systemd_daemon_reload':
            command         => '/usr/bin/systemctl daemon-reload',
            refreshonly     => true,
            require         => Package['systemd']
        }

        /* Socket settings */
        if ($port_alternative) {
            $systemd_socket_settings = {
                'ListenStream' => ['', $port, $port_alternative]
            }
        } else {
            $systemd_socket_settings = {
                'ListenStream' => ['', $port]
            }
        }

        /* Create drop in for SSH socket */
        basic_settings::systemd_drop_in { 'ssh_socket_settings':
            target_unit     => 'ssh.socket',
            socket          => $systemd_socket_settings,
            daemon_reload   => 'ssh_systemd_daemon_reload',
            require         => Package['openssh-server']
        }

        /* Disable SSH server service */
        service { 'ssh.service':
            ensure      => undef,
            enable      => false,
            require     => File['/etc/ssh/sshd_config.d/99-custom.conf'],
            subscribe   => File['/etc/ssh/sshd_config.d/99-custom.conf']
        }

        /* Ensure that ssh is always running */
        service { 'ssh.socket':
            ensure      => running,
            enable      => true,
            require     => Package['openssh-server']
        }
    } else {
        /* Ensure that ssh is always running */
        service { 'ssh':
            ensure      => running,
            enable      => true,
            require     => File['/etc/ssh/sshd_config.d/99-custom.conf'],
            subscribe   => File['/etc/ssh/sshd_config.d/99-custom.conf']
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
