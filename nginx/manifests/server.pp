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
    $http3_enable                       = false,

    # Global settings for given ports; This values can only set onces
    $fastopen                           = 0,
    $reuseport                          = false,

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
    $http_options_allow                 = true,
    $http_options_allow_origin          = '*',
    $http_options_allow_methods         = 'GET, POST',
    $http_options_allow_headers         = 'origin, x-requested-with, content-type, accept, cache-control',
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
    $redirect_ip                        = undef,
    $redirect_ipv6                      = undef,
    $redirect_http_port                 = undef,
    $redirect_https_port                = undef,
    $redirect_ssl_protocols             = undef,
    $redirect_ssl_ciphers               = undef,
    $redirect_certificate               = undef,
    $redirect_certificate_key           = undef,

    $restart_service                    = true
  ) {

    /* Check if TCP fast open is enabled */
    if ($basic_settings::kernel_tcp_fastopen == 3 and $fastopen > 0) {
        $tcp_fastopen = true
    } else {
        $tcp_fastopen = false
    }

    /* Check if HTTP/2 or HTTP/3 is allowed */
    if ($https_enable and $ssl_certificate != undef and $ssl_certificate_key != undef) {
        $http2_active = $http2_enable
        if ($ssl_protocols != undef and $ssl_protocols =~ 'TLSv1.3') {
            $http3_active = $http3_enable
        } elsif ($nginx::ssl_protocols =~ 'TLSv1.3') {
            $http3_active = $http3_enable
        } else {
            $http3_active = false
        }

        /* Check if redirect_certificate is not given */
        if ($redirect_certificate != undef and $redirect_certificate_key != undef) {
            $redirect_certificate_correct = $redirect_certificate
            $redirect_certificate_key_correct = $redirect_certificate_key
        } else {
            $redirect_certificate_correct = $ssl_certificate
            $redirect_certificate_key_correct = $ssl_certificate_key
        }
    } else {
        $http2_active = false
        $http3_active = false
        $redirect_certificate_correct = undef
        $redirect_certificate_key_correct = undef
    }

    /* Split server_name from by space, we need only the first in template to use as a redirect*/
    if ($redirect_from and $redirect_from != '') {
        $redirect_to = split($server_name, ' ')[0]
    }

    /* Set IPv4 */
    if ($redirect_ip == undef) {
        $redirect_ip_correct = $ip
    } else {
        $redirect_ip_correct = $redirect_ip
    }

    /* Set IPv6 */
    if ($redirect_ipv6 == undef) {
        $redirect_ipv6_correct = $ipv6
    } else {
        $redirect_ipv6_correct = $redirect_ipv6
    }

    /* Set HTTP port */
    if ($redirect_http_port == undef) {
        $redirect_http_port_correct = $http_port
    } else {
        $redirect_http_port_correct = $redirect_http_port
    }

    /* Check if the HTTP port are the same */
    if ($redirect_http_port_correct == $http_port) {
        $redirect_http_options = false
    } else {
        $redirect_http_options = true
    }

    /* Set HTTP port */
    if ($redirect_https_port == undef) {
        $redirect_https_port_correct = $https_port
    } else {
        $redirect_https_port_correct = $redirect_https_port
    }

    /* Check if the HTTP port are the same */
    if ($redirect_https_port_correct == $https_port) {
        $redirect_https_options = false
    } else {
        $redirect_https_options = true
    }

    /* Set SSL protocols */
    if ($redirect_ssl_protocols == undef) {
        $redirect_ssl_protocols_correct = $ssl_protocols
    } else {
        $redirect_ssl_protocols_correct = $redirect_ssl_protocols
    }

    /* Set SSL ciphers */
    if ($redirect_ssl_ciphers == undef) {
        $redirect_ssl_ciphers_correct = $ssl_ciphers
    } else {
        $redirect_ssl_ciphers_correct = $redirect_ssl_ciphers
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
