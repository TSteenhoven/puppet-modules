class rabbitmq::tcp(
        $tcp_enable             = false,
        $tcp_port               = 5672,
        $ssl_ca_certificate     = undef,
        $ssl_certificate        = undef,
        $ssl_certificate_key    = undef,
        $ssl_port               = 5671,
        $ssl_protocols          = {
            '1' => 'tlsv1.3',
            '2' => 'tlsv1.2'
        },
        $ssl_ciphers = {
            '1'     => 'TLS_AES_256_GCM_SHA384',
            '2'     => 'TLS_AES_128_GCM_SHA256',
            '3'     => 'TLS_CHACHA20_POLY1305_SHA256',
            '4'     => 'TLS_AES_128_CCM_SHA256',
            '5'     => 'TLS_AES_128_CCM_8_SHA256',
            '6'     => 'ECDHE-ECDSA-AES256-GCM-SHA384',
            '7'     => 'ECDHE-RSA-AES256-GCM-SHA384',
            '8'     => 'ECDH-ECDSA-AES256-GCM-SHA384',
            '9'     => 'ECDH-RSA-AES256-GCM-SHA384',
            '10'    => 'DHE-RSA-AES256-GCM-SHA384',
            '11'    => 'DHE-DSS-AES256-GCM-SHA384',
            '12'    => 'ECDHE-ECDSA-AES128-GCM-SHA256',
            '13'    => 'ECDHE-RSA-AES128-GCM-SHA256',
            '14'    => 'ECDH-ECDSA-AES128-GCM-SHA256',
            '15'    => 'ECDH-RSA-AES128-GCM-SHA256',
            '16'    => 'DHE-RSA-AES128-GCM-SHA256',
            '17'    => 'DHE-DSS-AES128-GCM-SHA256'
        }
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
