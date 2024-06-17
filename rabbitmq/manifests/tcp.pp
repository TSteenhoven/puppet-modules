class rabbitmq::tcp(
        $tcp_enable             = false,
        $tcp_port               = 5672,
        $ssl_ca_certificate     = undef,
        $ssl_certificate        = undef,
        $ssl_certificate_key    = undef,
        $ssl_port               = 5671,
        $ssl_protocols          = ['tlsv1.3', 'tlsv1.2'],
        $ssl_ciphers = [
            'ECDHE-ECDSA-AES128-GCM-SHA256',
            'ECDHE-RSA-AES128-GCM-SHA256',
            'ECDHE-ECDSA-AES256-GCM-SHA384',
            'ECDHE-RSA-AES256-GCM-SHA384',
            'ECDHE-ECDSA-CHACHA20-POLY1305',
            'ECDHE-RSA-CHACHA20-POLY1305',
            'DHE-RSA-AES128-GCM-SHA256',
            'DHE-RSA-AES256-GCM-SHA384',
            'DHE-RSA-CHACHA20-POLY1305'
        ]
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
