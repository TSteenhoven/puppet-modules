define basic_settings::login_user(
    $home,
    $uid,
    $gid,
    $password,
    $ensure             = present,
    $groups             = [],
    $bash_profile       = undef,
    $bashrc             = undef,
    $bash_aliases       = undef,
    $authorized_keys    = undef,
    $shell              = '/bin/bash',
    $disable_group      = false,
    $home_enable        = true,
    $home_force         = false,
    $home_purge         = false,
    $home_recurse       = false,
    $home_source        = undef
) {

    /* Create only user group when group is disabled */
    if (!$disable_group) {
        group { $name:
            ensure      => $ensure,
            gid         => $gid
        }
    }

    /* Create user */
    user { $name:
        ensure      => $ensure,
        uid         => $uid,
        gid         => $gid,
        groups      => $groups,
        shell       => $shell,
        home        => $home,
        managehome  => false,
        password    => $password
    }

    if ($ensure == present) {
        Group[$name] -> User[$name]
    } else {
        User[$name] -> Group[$name]
    }

    if ($home_enable) {
        /* Make home dir */
        if ($home_source) {
            file { $home:
                ensure  => $ensure ? { absent => undef, default => directory },
                owner   => $uid,
                group   => $gid,
                force   => $home_force,
                purge   => $home_purge,
                recurse => $home_recurse,
                source  => $home_source,
                mode    => '0700'
            }
        } else {
            file { $home:
                ensure  => $ensure ? { absent => undef, default => directory },
                owner   => $uid,
                group   => $gid,
                force   => $home_force,
                purge   => $home_purge,
                recurse => $home_recurse,
                mode    => '0700'
            }
        }

        /* Create ssh dir */
        file { "${home}/.ssh":
            ensure  => $ensure ? { absent => undef, default => directory },
            owner   => $uid,
            group   => $gid,
            mode    => '0700',
            require => File[$home]
        }

        /* Create authorized_keys file */
        if ($authorized_keys != undef) {
            file { "${home}/.ssh/authorized_keys":
                ensure  => $ensure ? { absent => absent, default => present },
                content => $authorized_keys,
                mode    => '0600',
                owner   => $uid,
                group   => $gid,
                require => File[$home]
            }
        }

        /* Create profile file */
        if ($bash_profile != undef) {
            file { "${home}/.profile":
                ensure  => $ensure ? { absent => absent, default => present },
                content => $bash_profile,
                owner   => $uid,
                group   => $gid,
                mode    => '0700',
                require => File[$home]
            }
        }

        /* Create bashrc file */
        if ($bashrc != undef) {
            file { "${home}/.bashrc":
                ensure  => $ensure ? { absent => absent, default => present },
                content => $bashrc,
                owner   => $uid,
                group   => $gid,
                mode    => '0700',
                require => File[$home]
            }
        }

        /* Create bash aliases file */
        if ($bash_aliases != undef) {
            file { "${home}/.bash_aliases":
                ensure  => $ensure ? { absent => absent, default => present },
                content => $bash_aliases,
                owner   => $uid,
                group   => $gid,
                mode    => '0700',
                require => File[$home]
            }
        }

        /* Create audit rules */
        if ($ensure and defined(Package['auditd'])) {
            basic_settings::security_audit { "${name}-ssh":
                rules => [
                    "-a always,exit -F arch=b32 -F path=${home}/.ssh -F perm=r -F auid!=unset -F key=ssh",
                    "-a always,exit -F arch=b64 -F path=${home}/.ssh -F perm=r -F auid!=unset -F key=ssh",
                    "-a always,exit -F arch=b32 -F path=${home}/.ssh -F perm=wa -F key=ssh",
                    "-a always,exit -F arch=b64 -F path=${home}/.ssh -F perm=wa -F key=ssh"
                ]
            }
        }
    }
}
