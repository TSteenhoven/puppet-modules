class rabbitmq::management(
        $ssl_ca_certificate     = undef,
        $ssl_certificate        = undef,
        $ssl_certificate_key    = undef,
        $ssl_port               = 15671,
        $ssl_protocols          = undef,
        $ssl_ciphers            = undef
    ) {

    /* Setup the plugin */
    exec { 'rabbitmq_management_plugin':
        command =>  'bash -c "(umask 27 && /usr/sbin/rabbitmq-plugins --quiet enable rabbitmq_management)"',
        unless  => '/usr/sbin/rabbitmq-plugins --quiet is_enabled rabbitmq_management',
        require => Package['rabbitmq-server']
    }

    /* Check if all cert variables are given */
    if ($ssl_ca_certificate != undef and $ssl_certificate != undef and $ssl_certificate_key != undef) {
        $https_allow = true
        $ssl_ca_certificate_correct = $ssl_ca_certificate
        $ssl_certificate_correct = $ssl_certificate
        $ssl_certificate_key_correct = $ssl_certificate_key
    } elsif ($rabbitmq::tcp::ssl_ca_certificate != undef and $rabbitmq::tcp::ssl_certificate != undef and $rabbitmq::tcp::ssl_certificate_key != undef) {
        $https_allow = true
        $ssl_ca_certificate_correct = $rabbitmq::tcp::ssl_ca_certificate
        $ssl_certificate_correct = $rabbitmq::tcp::ssl_certificate
        $ssl_certificate_key_correct = $rabbitmq::tcp::ssl_certificate_key
    } else {
        $https_allow = false
        $ssl_ca_certificate_correct = undef
        $ssl_certificate_correct = undef
        $ssl_certificate_key_correct = undef
    }

    /* Check if https is active */
    if ($https_allow) {
        /* Set SSL protocols */
        if ($ssl_protocols == undef) {
            if ($rabbitmq::tcp::ssl_protocols == undef) {
                $ssl_protocols_correct = []
            } else {
                $ssl_protocols_correct = $rabbitmq::tcp::ssl_protocols
            }
        } else {
            $ssl_protocols_correct = $ssl_protocols
        }

        /* Set SSL ciphers */
        if ($ssl_ciphers == undef) {
            if ($rabbitmq::tcp::ssl_ciphers == undef) {
                $ssl_ciphers_correct = []
            } else {
                $ssl_ciphers_correct = $rabbitmq::tcp::ssl_ciphers
            }
        } else {
            $ssl_ciphers_correct = $ssl_ciphers
        }
    } else {
        $ssl_ciphers_correct = []
    }

    /* Create management config file */
    file { '/etc/rabbitmq/conf.d/management.conf':
        ensure  => file,
        content => template('rabbitmq/management.conf'),
        owner   => 'rabbitmq',
        group   => 'rabbitmq',
        mode    => '0600',
        notify  => Service['rabbitmq-server'],
        require => File['rabbitmq_config_dir']
    }
}
