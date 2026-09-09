# @summary Manages one Nginx virtual host.
#
# lint:ignore:140chars
# This defined type renders `/etc/nginx/conf.d/<title>.conf`, optional fallback `security.txt` content, HTTP/HTTPS listeners, redirects, PHP-FPM locations, static or reverse-proxy locations, TLS settings, and secure-by-default response headers. Applications can override or disable individual headers when they intentionally manage those headers themselves. Strict CSP or HSTS settings can break applications that depend on external scripts, stylesheets, APIs, iframes, analytics, or legacy TLS clients, so vhost-specific overrides should be tested.
# lint:endignore
#
# @example Static HTTPS vhost with secure defaults
#   nginx::server { 'www.example.org':
#     docroot             => '/var/www/www.example.org',
#     server_name         => 'www.example.org',
#     https_enable        => true,
#     ssl_certificate     => '/etc/letsencrypt/live/www.example.org/fullchain.pem',
#     ssl_certificate_key => '/etc/letsencrypt/live/www.example.org/privkey.pem',
#   }
#
# @example Reverse proxy with an application-specific CSP
#   nginx::server { 'app.example.org':
#     docroot                 => undef,
#     server_name             => 'app.example.org',
#     try_files               => false,
#     content_security_policy => "default-src 'self'; frame-ancestors 'none'",
#     location_directives     => [
#       'proxy_pass https://127.0.0.1:8443;',
#       'proxy_ssl_verify off;',
#     ],
#   }
#
# @param access_log
#   Optional access log directive value. `undef` lets the template use its default behavior.
#
# @param acme_enable
#   Enables ACME challenge handling in the vhost template.
#
# @param allow_directories
#   Controls whether directory access is allowed by the generated root location.
#
# @param backlog
# lint:ignore:140chars
#   Listener backlog behavior. `-1` disables explicit backlog, `0` inherits the kernel connection limit, and values greater than zero set a custom backlog.
# lint:endignore
#
# @param client_max_body_size
#   Optional `client_max_body_size` value for the vhost.
#
# @param content_security_policy
#   CSP header value. `true` uses the module default, a string sets a vhost policy, and `false` disables the managed header.
#
# @param default_server
#   Marks this vhost as the default server for generated listen directives.
#
# @param directives
#   Additional raw directives rendered at the server context.
#
# @param docroot
#   Document root for static/PHP locations. `undef` is common for pure reverse proxy vhosts.
#
# @param error_log
#   Optional error log directive value.
#
# @param fastcgi_read_timeout
#   Optional PHP FastCGI read timeout.
#
# @param fastopen
#   TCP Fast Open queue length used when the kernel class allows TFO.
#
# @param http2_enable
#   Enables HTTP/2 for HTTPS listeners when certificates are configured.
#
# @param http3_enable
#   Enables HTTP/3 when HTTPS and TLS 1.3 are active.
#
# @param http_enable
#   Creates HTTP listeners when `true`.
#
# @param http_ipv6
#   Creates IPv6 HTTP listeners when `true` and IPv6 is enabled.
#
# @param http_port
#   HTTP listen port.
#
# @param https_enable
#   Creates HTTPS listeners when `true`.
#
# @param https_force
#   Forces HTTP to HTTPS redirects when `true`.
#
# @param https_ipv6
#   Creates IPv6 HTTPS listeners when `true` and IPv6 is enabled.
#
# @param https_port
#   HTTPS listen port.
#
# @param ip
#   Optional IPv4 listen address.
#
# @param ipv6
#   Optional IPv6 listen address.
#
# @param keepalive_request_file
#   Optional file path used by the template for keepalive request handling.
#
# @param location_directives
#   Raw directives rendered in the main location block, often proxy directives.
#
# @param location_internal
#   Marks the main location internal when `true`.
#
# @param locations
#   Additional location hashes rendered by the template.
#
# @param php_fpm_directives
#   Additional raw directives rendered into the PHP-FPM location.
#
# @param php_fpm_enable
#   Enables PHP-FPM location rendering when `true`.
#
# @param php_fpm_location
#   Regex or location expression for PHP requests.
#
# @param php_fpm_location_inc
#   Regex or location expression for PHP include files.
#
# @param php_fpm_uri
#   FastCGI upstream URI, commonly a Unix socket.
#
# @param redirect_certificate
#   Optional certificate path for the redirect server. `undef` inherits the main certificate when available.
#
# @param redirect_certificate_key
#   Optional key path for the redirect server. `undef` inherits the main key.
#
# @param redirect_certificate_trusted
#   Optional trusted certificate path for the redirect server.
#
# @param redirect_from
#   Optional legacy host name that should redirect to the first `server_name`.
#
# @param redirect_http_port
#   Optional HTTP port for the redirect server.
#
# @param redirect_https_port
#   Optional HTTPS port for the redirect server.
#
# @param redirect_ip
#   Optional IPv4 listen address for the redirect server.
#
# @param redirect_ipv6
#   Optional IPv6 listen address for the redirect server.
#
# @param redirect_ssl_ciphers
#   Optional TLS cipher list for the redirect server.
#
# @param redirect_ssl_conf_command
#   Optional OpenSSL configuration commands for the redirect server.
#
# @param redirect_ssl_ocsp
#   Optional OCSP setting for the redirect server.
#
# @param redirect_ssl_protocols
#   Optional TLS protocol string for the redirect server.
#
# @param referrer_policy
#   Referrer-Policy header value. `true` uses the module default, a string sets a vhost policy, and `false` disables the managed header.
#
# @param restart_service
#   Notifies the Nginx service when the vhost file changes if `true`.
#
# @param reuseport
#   Enables `reuseport` on generated listen directives.
#
# @param securitytxt_contacts
#   Vhost-specific security.txt contacts. `undef` inherits the class default or monitoring mail fallback.
#
# @param securitytxt_enable
#   Vhost-specific security.txt switch. `undef` inherits the class default.
#
# @param securitytxt_encryption
#   Optional vhost-specific security.txt Encryption URL.
#
# @param securitytxt_expires_days
#   Optional vhost-specific security.txt expiry window in days.
#
# @param securitytxt_policy
#   Optional vhost-specific security.txt Policy URL.
#
# @param securitytxt_preferred_languages
#   Optional vhost-specific Preferred-Languages list.
#
# @param server_name
#   Space-separated Nginx `server_name` value. `undef` lets the title act as the primary name for fallback values.
#
# @param ssl_buffer_size
#   Optional `ssl_buffer_size` value.
#
# @param ssl_certificate
#   TLS certificate path for the main HTTPS server.
#
# @param ssl_certificate_key
#   TLS private key path for the main HTTPS server.
#
# @param ssl_certificate_trusted
#   Optional trusted certificate path for OCSP or upstream validation.
#
# @param ssl_ciphers
#   TLS cipher list rendered as a colon-separated string.
#
# @param ssl_conf_command
#   OpenSSL configuration commands rendered for the main HTTPS server.
#
# @param ssl_ocsp
#   Enables OCSP stapling-related template output when `true`.
#
# @param ssl_protocols
#   Optional TLS protocol string. `undef` inherits `nginx::ssl_protocols`.
#
# @param ssl_session_cache
#   Optional `ssl_session_cache` value.
#
# @param ssl_session_timeout
#   Optional `ssl_session_timeout` value.
#
# @param strict_transport_security
#   HSTS header value. `true` uses the module default, a string sets a vhost value, and `false` disables the managed header.
#
# @param try_files
#   Root-location `try_files` behavior. `true` uses `$uri $uri/ =404`, a string supplies custom arguments, and `false` omits the directive.
#
# @param x_content_type_options
#   X-Content-Type-Options header value. `true` uses `nosniff`, a string sets a vhost value, and `false` disables the managed header.
#
# @param x_frame_options
#   X-Frame-Options header value. `true` uses `SAMEORIGIN`, a string sets a vhost value, and `false` disables the managed header.
#
# @api public
define nginx::server (
  Optional[String]         $access_log                      = undef,
  Boolean                  $acme_enable                     = false,
  Boolean                  $allow_directories               = false,
  Integer                  $backlog                         = -1, # Global settings; -1: Disabled, 0: Kernel; >0: Custom value
  Optional[String]         $client_max_body_size            = undef,
  Variant[Boolean, String] $content_security_policy         = true,
  Boolean                  $default_server                  = false,
  Array                    $directives                      = [],
  Optional[String]         $docroot                         = undef,
  Optional[String]         $error_log                       = undef,
  Optional[Integer]        $fastcgi_read_timeout            = undef,
  Integer                  $fastopen                        = 0, # Global settings
  Boolean                  $http2_enable                    = true,
  Boolean                  $http3_enable                    = true,
  Boolean                  $http_enable                     = true,
  Boolean                  $http_ipv6                       = true,
  Integer                  $http_port                       = 80,
  Boolean                  $https_enable                    = false,
  Boolean                  $https_force                     = false,
  Boolean                  $https_ipv6                      = true,
  Integer                  $https_port                      = 443,
  Optional[String]         $ip                              = undef,
  Optional[String]         $ipv6                            = undef,
  Optional[String]         $keepalive_request_file          = undef,
  Array                    $location_directives             = [],
  Boolean                  $location_internal               = false,
  Array                    $locations                       = [],
  Array                    $php_fpm_directives              = [],
  Boolean                  $php_fpm_enable                  = true,
  String                   $php_fpm_location                = '~* \.php$',
  String                   $php_fpm_location_inc            = '~* \.php.inc$',
  String                   $php_fpm_uri                     = 'unix:/run/php/php-fpm.sock',
  Optional[String]         $redirect_certificate            = undef,
  Optional[String]         $redirect_certificate_key        = undef,
  Optional[String]         $redirect_certificate_trusted    = undef,
  Optional[String]         $redirect_from                   = undef,
  Optional[String]         $redirect_http_port              = undef,
  Optional[String]         $redirect_https_port             = undef,
  Optional[String]         $redirect_ip                     = undef,
  Optional[String]         $redirect_ipv6                   = undef,
  Optional[Array]          $redirect_ssl_ciphers            = undef,
  Optional[Hash]           $redirect_ssl_conf_command       = undef,
  Optional[String]         $redirect_ssl_ocsp               = undef,
  Optional[String]         $redirect_ssl_protocols          = undef,
  Variant[Boolean, String] $referrer_policy                 = true,
  Boolean                  $restart_service                 = true,
  Boolean                  $reuseport                       = false, # Global settings
  Optional[Array]          $securitytxt_contacts            = undef,
  Optional[Boolean]        $securitytxt_enable              = undef,
  Optional[String]         $securitytxt_encryption          = undef,
  Optional[Integer]        $securitytxt_expires_days        = undef,
  Optional[String]         $securitytxt_policy              = undef,
  Optional[Array]          $securitytxt_preferred_languages = undef,
  Optional[String]         $server_name                     = undef,
  Optional[Integer]        $ssl_buffer_size                 = undef,
  Optional[String]         $ssl_certificate                 = undef,
  Optional[String]         $ssl_certificate_key             = undef,
  Optional[String]         $ssl_certificate_trusted         = undef,
  Array                    $ssl_ciphers                     = [
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
    'DHE-RSA-AES256-GCM-SHA384', 'DHE-RSA-CHACHA20-POLY1305',
  ],
  Hash                     $ssl_conf_command                = {
    'Ciphersuites' => [
      'TLS_AES_128_GCM_SHA256',
      'TLS_AES_256_GCM_SHA384',
      'TLS_CHACHA20_POLY1305_SHA256',
    ],
    'SignatureAlgorithms' => [
      'ECDSA+SHA512',
      'ECDSA+SHA384',
      'ECDSA+SHA256',
      'RSA-PSS+SHA512',
      'RSA-PSS+SHA384',
      'RSA-PSS+SHA256',
      'RSA+SHA512',
      'RSA+SHA384',
      'RSA+SHA256',
    ],
  },
  Boolean                  $ssl_ocsp                        = false,
  Optional[String]         $ssl_protocols                   = undef,
  Optional[String]         $ssl_session_cache               = undef,
  Optional[String]         $ssl_session_timeout             = undef,
  Variant[Boolean, String] $strict_transport_security       = true,
  Variant[Boolean, String] $try_files                       = true,
  Variant[Boolean, String] $x_content_type_options          = true,
  Variant[Boolean, String] $x_frame_options                 = true,
) {
  if (defined(Class['nginx'])) {
    # Create security.txt file path
    $security_dir = "/etc/nginx/security/${name}"
    $securitytxt_file = "${security_dir}/security.txt"

    # Use the first server_name as the public host for Canonical and fallback contacts.
    if ($server_name != undef and $server_name != '') {
      $securitytxt_server_name = split($server_name, ' ')[0]
    } else {
      $securitytxt_server_name = $name
    }

    # Prefer explicit vhost contacts, then nginx-wide contacts, then monitoring mail.
    if ($securitytxt_contacts != undef) {
      $securitytxt_contacts_correct = $securitytxt_contacts
    } elsif ($nginx::securitytxt_contacts != undef) {
      $securitytxt_contacts_correct = $nginx::securitytxt_contacts
    } elsif (defined(Class['basic_settings::monitoring'])) {
      # basic_settings::monitoring::mail_to is an address, so add mailto: when needed.
      $securitytxt_contacts_correct = $basic_settings::monitoring::mail_to ? {
        /^(mailto:|https:\/\/|tel:)/ => [$basic_settings::monitoring::mail_to],
        default                     => ["mailto:${basic_settings::monitoring::mail_to}"],
      }
    } else {
      # Last resort: use the primary vhost name so the generated Contact is domain-local.
      $securitytxt_contacts_correct = ["mailto:info@${securitytxt_server_name}"]
    }

    # Let each vhost opt out, otherwise follow the nginx-wide default.
    if ($securitytxt_enable != undef) {
      $securitytxt_enable_correct = $securitytxt_enable
    } else {
      $securitytxt_enable_correct = $nginx::securitytxt_enable
    }

    # Optional fields can be set per vhost or inherited from nginx.
    if ($securitytxt_policy != undef) {
      $securitytxt_policy_correct = $securitytxt_policy
    } else {
      $securitytxt_policy_correct = $nginx::securitytxt_policy
    }

    # Prefer a vhost-specific Encryption URL; otherwise inherit the nginx-wide default.
    if ($securitytxt_encryption != undef) {
      $securitytxt_encryption_correct = $securitytxt_encryption
    } else {
      $securitytxt_encryption_correct = $nginx::securitytxt_encryption
    }

    # Prefer vhost-specific languages; otherwise use the nginx-wide language list.
    if ($securitytxt_preferred_languages != undef) {
      $securitytxt_preferred_languages_correct = $securitytxt_preferred_languages
    } else {
      $securitytxt_preferred_languages_correct = $nginx::securitytxt_preferred_languages
    }

    # Prefer a vhost-specific expiry window; otherwise use the nginx-wide value.
    if ($securitytxt_expires_days != undef) {
      $securitytxt_expires_days_correct = $securitytxt_expires_days
    } else {
      $securitytxt_expires_days_correct = $nginx::securitytxt_expires_days
    }

    # A proxied vhost is detected from the same location_directives used by location /.
    $securitytxt_proxy_pass_directives = filter($location_directives) |$directive| {
      String($directive) =~ /^\s*proxy_pass\s+/
    }
    $securitytxt_proxy_header_directives = filter($location_directives) |$directive| {
      String($directive) =~ /^\s*proxy_set_header\s+/
    }

    # Reuse only the first proxy_pass target and ask the backend for security.txt explicitly.
    if (!empty($securitytxt_proxy_pass_directives)) {
      $securitytxt_proxy_pass_target      = regsubst(
        String($securitytxt_proxy_pass_directives[0]),
        '^\s*proxy_pass\s+([^;\s#]+).*$',
        '\1'
      )
      $securitytxt_proxy_pass_base        = regsubst($securitytxt_proxy_pass_target, '/+$', '')
      $securitytxt_proxy_pass_securitytxt = "${securitytxt_proxy_pass_base}/.well-known/security.txt"
      $securitytxt_proxy_enable           = true
    } else {
      $securitytxt_proxy_pass_target      = undef
      $securitytxt_proxy_pass_base        = undef
      $securitytxt_proxy_pass_securitytxt = undef
      $securitytxt_proxy_enable           = false
    }

    # Preferred-Languages is optional; an empty array simply omits the field.
    if ($securitytxt_preferred_languages_correct != undef and !empty($securitytxt_preferred_languages_correct)) {
      $securitytxt_languages = join($securitytxt_preferred_languages_correct, ',')
    } else {
      $securitytxt_languages = ''
    }

    # Invalid Contact values suppress the managed file instead of failing the catalog.
    $securitytxt_invalid_contacts = filter($securitytxt_contacts_correct) |$securitytxt_contact_value| {
      String($securitytxt_contact_value) !~ /^(mailto:|https:\/\/|tel:)/
    }

    # Invalid security.txt input disables the managed fallback instead of failing the catalog.
    $securitytxt_active = (
      $securitytxt_enable_correct
      and ($securitytxt_expires_days_correct > 0)
      and !empty($securitytxt_contacts_correct)
      and empty($securitytxt_invalid_contacts)
    )

    # security.txt canonical always points at the standard well-known URL for this vhost.
    $securitytxt_canonical_correct = "https://${securitytxt_server_name}/.well-known/security.txt"

    # Only calculate Expires after validating the configured day count.
    if ($securitytxt_expires_days_correct > 0) {
      $securitytxt_expires = (Timestamp() + Timespan("${securitytxt_expires_days_correct}-00:00:00")).strftime('%Y-%m-%dT00:00:00Z')
    } else {
      $securitytxt_expires = undef
    }

    # Nginx named locations only get safe identifier characters.
    $securitytxt_location_name = regsubst($name, '[^A-Za-z0-9_]', '_', 'G')

    # Nginx map destination variables are global to http; use a short vhost hash to avoid variables_hash_bucket_size failures.
    $security_headers_variable_name = "sh_${regsubst(stdlib::sha256($name), '^(.{12}).*$', '\1')}"

    # Resolve Content-Security-Policy to the default, a vhost override, or false for opt-out.
    $content_security_policy_default = "default-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self'"
    $content_security_policy_correct = $content_security_policy ? {
      true    => $content_security_policy_default,
      default => $content_security_policy,
    }

    # Resolve Referrer-Policy to the default, a vhost override, or false for opt-out.
    $referrer_policy_default = 'same-origin'
    $referrer_policy_correct = $referrer_policy ? {
      true    => $referrer_policy_default,
      default => $referrer_policy,
    }

    # Resolve Strict-Transport-Security to the default, a vhost override, or false for opt-out.
    $strict_transport_security_default = 'max-age=31536000'
    $strict_transport_security_correct = $strict_transport_security ? {
      true    => $strict_transport_security_default,
      default => $strict_transport_security,
    }

    # Resolve root-location try_files to the default, custom arguments, or false for opt-out.
    $try_files_default = '$uri $uri/ =404'
    $try_files_correct = $try_files ? {
      true    => $try_files_default,
      default => $try_files,
    }

    # Resolve X-Content-Type-Options to the default, a vhost override, or false for opt-out.
    $x_content_type_options_default = 'nosniff'
    $x_content_type_options_correct = $x_content_type_options ? {
      true    => $x_content_type_options_default,
      default => $x_content_type_options,
    }

    # Resolve X-Frame-Options to the default, a vhost override, or false for opt-out.
    $x_frame_options_default = 'SAMEORIGIN'
    $x_frame_options_correct = $x_frame_options ? {
      true    => $x_frame_options_default,
      default => $x_frame_options,
    }

    # Check if TCP fast open is enabled
    if (defined(Class['basic_settings::kernel'])) {
      # Check if valid backlog value is given
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

      # Check TCP fast open
      if ($basic_settings::kernel::tcp_fastopen == 3 and $fastopen > 0) {
        $tcp_fastopen = true
      } else {
        $tcp_fastopen = false
      }

      # Check if IPv6 is active
      if ($basic_settings::kernel::ip_version_v6) {
        $http_ipv6_correct = $http_ipv6
        $https_ipv6_correct = $https_ipv6
      } else {
        $http_ipv6_correct = false
        $https_ipv6_correct = false
      }
    } else {
      # Check if valid backlog value is given
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

    # Check if HTTP/2 or HTTP/3 is allowed
    if ($https_enable and $ssl_certificate != undef and $ssl_certificate_key != undef) {
      $http2_active = $http2_enable
      if ($ssl_protocols != undef and $ssl_protocols =~ 'TLSv1.3') {
        $http3_active = $http3_enable
      } elsif ($nginx::ssl_protocols =~ 'TLSv1.3') {
        $http3_active = $http3_enable
      } else {
        $http3_active = false
      }

      # Check if redirect_certificate is not given
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

    # Split server_name from by space, we need only the first in template to use as a redirect
    if ($redirect_from and $redirect_from != '') {
      $redirect_to = split($server_name, ' ')[0]
    }

    # Set IPv4
    if ($redirect_ip == undef) {
      $redirect_ip_correct = $ip
    } else {
      $redirect_ip_correct = $redirect_ip
    }

    # Set IPv6
    if ($redirect_ipv6 == undef) {
      $redirect_ipv6_correct = $ipv6
    } else {
      $redirect_ipv6_correct = $redirect_ipv6
    }

    # Set HTTP port
    if ($redirect_http_port == undef) {
      $redirect_http_port_correct = $http_port
    } else {
      $redirect_http_port_correct = $redirect_http_port
    }

    # Check if the HTTP port are the same
    if ($redirect_http_port_correct == $http_port) {
      $redirect_http_options = false
    } else {
      $redirect_http_options = true
    }

    # Set HTTP port
    if ($redirect_https_port == undef) {
      $redirect_https_port_correct = $https_port
    } else {
      $redirect_https_port_correct = $redirect_https_port
    }

    # Check if the HTTP port are the same
    if ($redirect_https_port_correct == $https_port) {
      $redirect_https_options = false
    } else {
      $redirect_https_options = true
    }

    # Set SSL protocols
    if ($redirect_ssl_protocols == undef) {
      $redirect_ssl_protocols_correct = $ssl_protocols
    } else {
      $redirect_ssl_protocols_correct = $redirect_ssl_protocols
    }

    # Set SSL conf
    if ($redirect_ssl_conf_command == undef) {
      $redirect_ssl_conf_command_correct = $ssl_conf_command
    } else {
      $redirect_ssl_conf_command_correct = $redirect_ssl_conf_command
    }

    # Set SSL ciphers
    $ssl_ciphers_correct = join($ssl_ciphers, ':')
    if ($redirect_ssl_ciphers == undef) {
      $redirect_ssl_ciphers_correct = $ssl_ciphers_correct
    } else {
      $redirect_ssl_ciphers_correct = join($redirect_ssl_ciphers, ':')
    }

    # Set SSL ocsp
    if ($redirect_ssl_ocsp == undef) {
      $redirect_ssl_ocsp_correct = $ssl_ocsp
    } else {
      $redirect_ssl_ocsp_correct = $redirect_ssl_ocsp
    }

    # Inform nginx when file is changed or created
    if ($restart_service) {
      file { "/etc/nginx/conf.d/${name}.conf":
        ensure  => file,
        content => template('nginx/server.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service['nginx'],
      }
    } else {
      file { "/etc/nginx/conf.d/${name}.conf":
        ensure  => file,
        content => template('nginx/server.conf'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
      }
    }

    # Rebuild security.txt after the vhost config changes by removing the stale fallback first.
    if ($securitytxt_active) {
      # Allow only the nginx runtime group to traverse the fallback directory.
      file { $security_dir:
        ensure  => directory,
        owner   => 'root',
        group   => $nginx::run_group,
        mode    => '0710',
        require => File['nginx_security'],
      }

      # Escape the generated path once before using it in the cleanup command.
      $securitytxt_file_shell = stdlib::shell_escape($securitytxt_file)
      exec { "nginx_securitytxt_remove_${name}":
        command     => "/bin/rm -f ${securitytxt_file_shell}",
        refreshonly => true,
        subscribe   => File["/etc/nginx/conf.d/${name}.conf"],
      }

      # The file resource creates missing files; replace false prevents daily Expires churn.
      file { $securitytxt_file:
        ensure  => file,
        owner   => 'root',
        group   => $nginx::run_group,
        mode    => '0640',
        content => template('nginx/security.txt'),
        replace => false,
        require => [File[$security_dir], Exec["nginx_securitytxt_remove_${name}"]],
      }
    } else {
      # Remove the security.txt file and directory
      file { [$security_dir, $securitytxt_file]:
        ensure  => absent,
        require => File['nginx_security'],
      }
    }
  } else {
    fail('The nginx class must be included before using the nginx::server defined type.')
  }
}
