define nginx::server(
    $docroot,

    $server_name                        = undef,
    $ip                                 = undef,
    $ipv6                               = undef,

    $http_enable                        = true,
    $http_port                          = 80,
    $http_ipv6                          = true,
    $default_server                     = false,

    $https_enable                       = false,
    $https_port                         = 443,
    $https_ipv6                         = true,

    $allow_acme                         = false,

    $https_force                        = false,
    $http2_enable                       = false,

    $keepalive_request_file             = undef,

    $ssl_protocols                      = undef,
    $ssl_ciphers                        = undef,
    $ssl_buffer_size                    = undef,
    $ssl_session_cache                  = undef,
    $ssl_session_timeout                = undef,
    $ssl_certificate                    = undef,
    $ssl_certificate_key                = undef,

    $fastcgi_read_timeout               = undef,

    $php_fpm_enable                     = true,
    $php_fpm_uri                        = 'unix:/run/php/php-fpm.sock',
    $allow_directories                  = false,
    $allow_http_options                 = true,
    $allow_http_options_origin          = '*',
    $allow_http_options_methods         = 'GET, POST',
    $allow_http_options_headers         = 'origin, x-requested-with, content-type, accept, cache-control',
    $try_files_enable                   = true,
    $catch_all_target                   = undef,

    $client_max_body_size               = undef,

    $access_log                         = undef,
    $error_log                          = undef,

    $location_internal                  = false,
    $location_directives                = [],
    $locations                          = [],
    $directives                         = [],
    $php_fpm_directives                 = [],

    $redirect_from                      = undef,
    $redirect_ipv6                      = true,
    $redirect_certificate               = undef,
    $redirect_certificate_key           = undef,

    $restart_service                    = true
  ) {

    /* Split server_name from by space, we need only the first in template to use as a redirect*/
    if ($redirect_from and $redirect_from != '') {
        $redirect_to = split($server_name, ' ')[0]
    }

    /* Inform nginx when file is changed or created */
    if ($restart_service) {
        file { "/etc/nginx/conf.d/${name}.conf":
            ensure  => file,
            content => template('nginx/server.conf'),
            owner   => 'root',
            group   => 'root',
            mode    => '0600',
            notify  => Service['nginx']
        }
    } else {
        file { "/etc/nginx/conf.d/${name}.conf":
            ensure  => file,
            content => template('nginx/server.conf'),
            owner   => 'root',
            group   => 'root',
            mode    => '0600'
        }
    }
}
