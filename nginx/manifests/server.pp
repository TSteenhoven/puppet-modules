define nginx::server(
    Optional[String]    $docroot                    = undef,
    Optional[String]    $access_log                 = undef,
    Optional[Boolean]   $allow_acme                 = false,
    Optional[Boolean]   $allow_directories          = false,
    Optional[Integer]   $backlog                    = -1, # Global settings; -1: Disabled, 0: Kernel; >0: Custom value
    Optional[Integer]   $client_max_body_size       = undef,
    Optional[Boolean]   $default_server             = false,
    Optional[Array]     $directives                 = [],
    Optional[String]    $error_log                  = undef,
    Optional[Integer]   $fastcgi_read_timeout       = undef,
    Optional[Integer]   $fastopen                   = 0, # Global settings
    Optional[Integer]   $hsts_max_age               = 604800,
    Optional[Boolean]   $http2_enable               = false,
    Optional[Boolean]   $http3_enable               = false,
    Optional[Boolean]   $http_enable                = true,
    Optional[Boolean]   $http_ipv6                  = true,
    Optional[Integer]   $http_port                  = 80,
    Optional[Boolean]   $https_enable               = false,
    Optional[Boolean]   $https_force                = false,
    Optional[Boolean]   $https_ipv6                 = true,
    Optional[Integer]   $https_port                 = 443,
    Optional[String]    $ip                         = undef,
    Optional[String]    $ipv6                       = undef,
    Optional[String]    $keepalive_request_file     = undef,
    Optional[Array]     $location_directives        = [],
    Optional[Boolean]   $location_internal          = false,
    Optional[Array]     $locations                  = [],
    Optional[Array]     $php_fpm_directives         = [],
    Optional[Boolean]   $php_fpm_enable             = true,
    Optional[String]    $php_fpm_location           = '~* \.php$',
    Optional[String]    $php_fpm_location_inc       = '~* \.php.inc$',
    Optional[String]    $php_fpm_uri                = 'unix:/run/php/php-fpm.sock',
    Optional[String]    $redirect_certificate       = undef,
    Optional[String]    $redirect_certificate_ke    = undef,
    Optional[String]    $redirect_from              = undef,
    Optional[String]    $redirect_http_port         = undef,
    Optional[String]    $redirect_https_port        = undef,
    Optional[String]    $redirect_ip                = undef,
    Optional[String]    $redirect_ipv6              = undef,
    Optional[Array]     $redirect_ssl_ciphers       = undef,
    Optional[String]    $redirect_ssl_protocols     = undef,
    Optional[Boolean]   $restart_service            = true,
    Optional[Boolean]   $reuseport                  = false, # Global settings
    Optional[String]    $server_name                = undef,
    Optional[Integer]   $ssl_buffer_size            = undef,
    Optional[String]    $ssl_certificate            = undef,
    Optional[String]    $ssl_certificate_key        = undef,
    Optional[Array]     $ssl_ciphers                = [
        'TLS_AES_128_GCM_SHA256',
        'TLS_AES_256_GCM_SHA384',
        'TLS_CHACHA20_POLY1305_SHA256',
        'ECDHE-ECDSA-AES128-GCM-SHA256',
        'ECDHE-RSA-AES128-GCM-SHA256',
        'ECDHE-ECDSA-AES256-GCM-SHA384',
        'ECDHE-RSA-AES256-GCM-SHA384',
        'ECDHE-ECDSA-CHACHA20-POLY1305',
        'ECDHE-RSA-CHACHA20-POLY1305',
        'DHE-RSA-AES128-GCM-SHA256',
        'DHE-RSA-AES256-GCM-SHA384','DHE-RSA-CHACHA20-POLY1305'
    ],
    Optional[String]    $ssl_protocols              = undef,
    Optional[String]    $ssl_session_cache          = undef,
    Optional[String]    $ssl_session_timeout        = undef,
    Optional[String]    $try_files_custom           = '$uri/ =404',
    Optional[Boolean]   $try_files_enable           = true
  ) {

    /* Check if TCP fast open is enabled */
    if (defined(Class['basic_settings::kernel'])) {
        /* Check if valid backlog value is given */
        if ($backlog == 0) {
            $backlog_active = true
            $backlog_value = $basic_settings::kernel::connection_max
        } elsif ($backlog > 0) {
            $backlog_active = true
            $backlog_value = $backlog
        } else {
            $backlog_active = false
            $backlog_value = undef
        }

        /* Check TCP fast open */
        if ($basic_settings::kernel::tcp_fastopen == 3 and $fastopen > 0) {
            $tcp_fastopen = true
        } else {
            $tcp_fastopen = false
        }

        /* Check if IPv6 is active */
        if ($basic_settings::kernel::ip_version_v6) {
            $http_ipv6_correct = $http_ipv6
            $https_ipv6_correct = $https_ipv6
        } else {
            $http_ipv6_correct = false
            $https_ipv6_correct = false
        }
    } else {
        /* Check if valid backlog value is given */
        if ($backlog > 0) {
            $backlog_active = true
            $backlog_value = $backlog
        } else {
            $backlog_active = false
            $backlog_value = undef
        }
        $tcp_fastopen = false
        $http_ipv6_correct = $http_ipv6
        $https_ipv6_correct = $https_ipv6
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
    if ($ssl_ciphers == undef) {
        $ssl_ciphers_correct = $ssl_ciphers
    } else {
        $ssl_ciphers_correct = join($ssl_ciphers, ':')
    }
    if ($redirect_ssl_ciphers == undef) {
        $redirect_ssl_ciphers_correct = $ssl_ciphers_correct
    } else {
        $redirect_ssl_ciphers_correct = join($redirect_ssl_ciphers, ':')
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
