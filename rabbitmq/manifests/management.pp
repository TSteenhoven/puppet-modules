class rabbitmq::management(

    ){

    /* Setup the plugin */
    exec { 'rabbitmq_management_plugin':
        command =>  'rabbitmq-plugins --quiet enable rabbitmq_management',
        unless  => 'rabbitmq-plugins --quiet is_enabled rabbitmq_management',
        require => Package['rabbitmq-server']
    }
}
