define basic_settings::login_sudo(
        String $rule,
    ) {

    file { "/etc/sudoers.d/${name}":
        ensure  => file,
        mode    => '0440',
        owner   => 'root',
        group   => 'root',
        content => "${rule}\n",
    }
}
