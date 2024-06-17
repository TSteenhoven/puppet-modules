class rabbitmq::tcp(
        $tcp_enable             = false,
        $tcp_port               = 5672,
        $ssl_ca_certificate     = undef,
        $ssl_certificate        = undef,
        $ssl_certificate_key    = undef,
        $ssl_port               = 5671
    ) {

    /* Check if all cert variables are given */
    if ($ssl_ca_certificate != undef and $ssl_certificate != undef and $ssl_certificate_key != undef) {
        $tls_allow = true
        $tcp_enable_correct = $tcp_enable
    } else {
        $tls_allow = false
        $tcp_enable_correct = true
    }

    /* Create management config file */
    file { '/etc/rabbitmq/conf.d/tcp.conf':
        ensure  => file,
        content => template('rabbitmq/tcp.conf'),
        owner   => 'rabbitmq',
        group   => 'rabbitmq',
        mode    => '0600',
        notify  => Service['rabbitmq-server'],
        require => File['rabbitmq_config_dir']
    }
}
