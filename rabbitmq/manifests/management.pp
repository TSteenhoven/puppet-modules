class rabbitmq::management(
        $ssl_ca_certificate     = undef,
        $ssl_certificate        = undef,
        $ssl_certificate_key    = undef,
    ){

    /* Setup the plugin */
    exec { 'rabbitmq_management_plugin':
        command =>  '(umask 27 && rabbitmq-plugins --quiet enable rabbitmq_management)',
        unless  => 'rabbitmq-plugins --quiet is_enabled rabbitmq_management',
        require => Package['rabbitmq-server']
    }

    /* Check if all cert variables are given */
    if ($ssl_ca_certificate != undef and $ssl_certificate != undef and $ssl_certificate_key != undef) {
        $https_allow = true
    } else {
        $https_allow = false
    }

    /* Create management config file */
    file { '/etc/rabbitmq/conf.d/management.conf':
        ensure  => file,
        content => template('rabbitmq/management.conf'),
        owner   => 'rabbitmq',
        group   => 'rabbitmq',
        mode    => '0600',
        notify  => Service['rabbitmq-server']
    }
}
