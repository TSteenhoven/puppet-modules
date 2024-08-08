class gitlab(
    String              $root_password,
    Optional[Integer]   $nice_level     = 12,
    Optional[String]    $root_email     = undef,
    Optional[String]    $server_fdqn    = undef
) {

    /* Try to get server fdqn */
    if ($server_fdqn == undef) {
        if (defined(Class['basic_settings'])) {
            $server_fdqn_correct = $basic_settings::server_fdqn
        } else {
            $server_fdqn_correct = $::networking['fqdn']
        }
    } else {
        $server_fdqn_correct = $server_fdqn
    }

    /* Try to get root email */
    if ($root_email == undef) {
        if (defined(Class['basic_settings::message'])) {
            $root_email_found = $basic_settings::message::mail_to
        } else {
            $root_email_found = 'root'
        }
    } else {
        $root_email_found = $root_email
    }

    /* Set email */
    if ($root_email_found == 'root') {
        $root_email_correct = "${root_email_correct}@${server_fdqn_correct}"
    } else {
        $root_email_correct = $root_email_found
    }

    /* Check if gitlab is installed exists */
    exec { 'gitlab_install':
        command => "GITLAB_ROOT_EMAIL=\"${root_email_correct}\" GITLAB_ROOT_PASSWORD=\"${root_password}\" EXTERNAL_URL=\"http://${server_fdqn}\" /usr/bin/apt-get install gitlab-ee",
        unless  => '/usr/bin/dpkg -l | /usr/bin/grep gitlab-ee',
        require => [Package['dpkg'], Package['grep']]
    }

    /* Create ssl directory */
    file { 'gitlab_ssl':
        path    => '/etc/gitlab/ssl',
        ensure  => directory,
        owner   => 'root',
        group   => 'roopt',
        mode    => '0700',
        require => Exec['gitlab_install']
    }

    if (defined(Package['systemd'])) {
        /* Reload systemd deamon */
        exec { 'gitlab_systemd_daemon_reload':
            command     => '/usr/bin/systemctl daemon-reload',
            refreshonly => true,
            require     => Package['systemd']
        }

        /* Check if basic settings is defined */
        if (defined(Class['basic_settings'])) {
            /* Disable Gitlab service */
            service { 'gitlab-runsvdir':
                ensure  => undef,
                enable  => false,
                require => Package['mysql-server']
            }

            /* Create drop in for services target */
            basic_settings::systemd_drop_in { 'gitlab_dependency':
                target_unit     => "${basic_settings::cluster_id}-services.target",
                unit            => {
                    'BindsTo'   => 'gitlab-runsvdir.service'
                },
                daemon_reload   => 'gitlab_systemd_daemon_reload',
                require         => Basic_settings::Systemd_target["${basic_settings::cluster_id}-services"]
            }
        }

        /* Get unit */
        if (defined(Class['basic_settings::message'])) {
            $unit = {
                'OnFailure' => 'notify-failed@%i.service'
            }
        } else {
            $unit = {}
        }

        /* Create drop in for nginx service */
        basic_settings::systemd_drop_in { 'gitlab_settings':
            target_unit     => 'gitlab-runsvdir.service',
            unit            => $unit,
            service         => {
                'Nice'          => "-${nice_level}"
            },
            daemon_reload   => 'gitlab_systemd_daemon_reload',
            require         => Exec['gitlab_install']
        }
    }
}
