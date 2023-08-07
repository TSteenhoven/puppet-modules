define basic_settings::sudo_rule(
        $rule,
    ) {

    file { "/etc/sudoers.d/${name}":
        ensure  => file,
        mode    => '0440',
        owner   => 'root',
        group   => 'root',
        content => "${rule}\n",
    }
}
