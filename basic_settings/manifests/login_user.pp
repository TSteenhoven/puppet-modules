define basic_settings::login_user(
    String                              $home,
    Integer                             $uid,
    Integer                             $gid,
    Sensitive[String]                   $password,
    Optional[Array]                     $authorized_keys    = undef,
    Optional[String]                    $bashrc             = undef,
    Optional[String]                    $bash_aliases       = undef,
    Optional[String]                    $bash_profile       = undef,
    Optional[Boolean]                   $disable_group      = false,
    Optional[Enum['present','absent']]  $ensure             = present,
    Optional[Array]                     $groups             = [],
    Optional[Boolean]                   $home_enable        = true,
    Optional[Boolean]                   $home_force         = false,
    Optional[Boolean]                   $home_purge         = false,
    Optional[Boolean]                   $home_recurse       = false,
    Optional[String]                    $home_source        = undef,
    Optional[String]                    $private_key        = undef,
    Optional[String]                    $shell              = '/bin/bash'
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
        if ($home_source != undef) {
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
                content => Sensitive.new(join($authorized_keys, "\n")),
                mode    => '0600',
                owner   => $uid,
                group   => $gid,
                require => File[$home]
            }
        }

        /* Create private key file */
        if ($private_key != undef) {
            file { "${home}/.ssh/private.key":
                ensure  => $ensure ? { absent => absent, default => present },
                source  => Sensitive.new($private_key),
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
