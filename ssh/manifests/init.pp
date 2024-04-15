
class ssh(
        $port                           = 22,
        $permit_root_login              = false,
        $password_authentication        = false,
        $password_authentication_users  = [],
        $allow_users                    = []
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

    if (defined(Package['auditd'])) {
        basic_settings::security_audit { 'ssh':
            rules => [
                '# SSH configuration',
                '-w /etc/ssh/sshd_config -p r -F auid!=unset -k sshd',
                '-w /etc/ssh/sshd_config.d -p r -F auid!=unset -k sshd',
                '-w /etc/ssh/sshd_config -p wa -k sshd',
                '-w /etc/ssh/sshd_config.d -p wa -k sshd',
                '-w /root/.ssh -p wa -k sshd',
                '# Suspicious activity',
                '/usr/bin/ssh -p x -k susp_activity'
            ]
        }
    }
}
