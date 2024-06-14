class rabbitmq(
    ) {

    /* Install erlang */
    package { 'erlang-base':
        ensure => installed
    }

    /* Install rabbitmq */
    package { 'rabbitmq-server':
        ensure => installed,
        require => Package['erlang-base']
    }
}
