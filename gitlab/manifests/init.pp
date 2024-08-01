class gitlab(
    String              $root_password,
    Optional[String]    $root_email  = undef,
    Optional[String]    $server_fdqn = undef
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
}
