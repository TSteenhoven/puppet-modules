class rabbitmq::management(
        $ssl_ca_certificate     = undef,
        $ssl_certificate        = undef,
        $ssl_certificate_key    = undef,
        $ssl_port               = 15671,
    ) {

    /* Setup the plugin */
    exec { 'rabbitmq_management_plugin':
        command =>  'bash -c "(umask 27 && rabbitmq-plugins --quiet enable rabbitmq_management)"',
        unless  => 'rabbitmq-plugins --quiet is_enabled rabbitmq_management',
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
