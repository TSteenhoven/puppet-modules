# @summary Manages one Nginx virtual host.
#
# This defined type renders `/etc/nginx/conf.d/<title>.conf`, optional fallback `security.txt` content, HTTP/HTTPS
# listeners, redirects, PHP-FPM locations, static or reverse-proxy locations, TLS settings, and secure-by-default
# response headers. Applications can override or disable individual headers when they intentionally manage those headers
# themselves. Strict CSP or HSTS settings can break applications that depend on external scripts, stylesheets, APIs,
# iframes, analytics, or legacy TLS clients, so vhost-specific overrides should be tested.
#
# Declare `nginx` first, but do not require the whole class from a vhost or a wrapper that changes Nginx configuration.
# That dependency orders the service before the configuration, whose notification orders it after the configuration,
# creating a cycle.
# The vhost already requires the package and configuration directory; use specific package or file resources for extra
# dependencies.
#
# Socket options (`backlog`, `fastopen`, `multipath`, `reuseport`) are shared per listen address, port and transport,
# including redirects. Repeated equal overrides are merged onto one listen directive in a shared `.inc` snippet.
# Conflicting effective values fail catalog compilation with the option and socket in the duplicate resource title.
# Disabled defaults contribute no override and do not disable another vhost's setting. Absent vhosts contribute nothing.
# Shared listeners must use the same address and port spelling.
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
#   Shared TCP listener backlog. Negative values omit an override; `0` inherits `basic_settings::kernel::connection_max`
#   when that class is declared, otherwise it omits the override. Positive values set a custom backlog. Matching
#   effective limits are merged, including an inherited kernel limit and the same explicit value.
#
# @param client_max_body_size
#   Optional `client_max_body_size` value for the vhost.
#
# @param content_security_policy
#   CSP header value. `true` uses the module default, a string sets a vhost policy, and `false` disables the managed
#   header.
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
# @param ensure
#   `present` manages the vhost; `absent` removes its configuration, security.txt fallback and both certificate checks
#   before deletion.
#
# @param error_log
#   Optional error log directive value.
#
# @param fastcgi_read_timeout
#   Optional PHP FastCGI read timeout.
#
# @param fastopen
#   Shared TCP Fast Open queue length. Positive values contribute an override only when `basic_settings::kernel`
#   is declared with `tcp_fastopen == 3`; other values or missing prerequisites omit the override.
#
# @param http2_enable
#   Enables HTTP/2 for HTTPS listeners when certificates are configured.
#
# @param http3_enable
#   Enables HTTP/3 when HTTPS and TLS 1.3 are active. Active vhosts and their redirects always enable `quic_gso`
#   and `quic_retry`; the shared `conf.d/0-quic.main` fragment enables `quic_bpf` while any managed HTTP/3 vhost
#   remains.
#   Requires an Nginx build with HTTP/3 and QUIC BPF support, Linux 5.7 or newer, UDP segmentation offloading,
#   and permission for the privileged master to load BPF programs. The systemd service receives an unlimited
#   locked-memory allowance for BPF maps; existing service hardening remains in place.
#   QUIC BPF routing requires `reuseport` on the UDP listener; enable it on at least one vhost per address/port pair.
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
#   Optional IPv6 listen address in square brackets, for example `[::1]`.
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
# @param monitoring_cert
#   Enables automatic local TLS checks with OpenITCOCKPIT and nonempty certificate/key values. `false` removes both
#   checks.
#
# @param multipath
#   Requests shared Multipath TCP on HTTP and HTTPS listeners, including redirects, but never on QUIC listeners.
#   Defaults to `false`, which contributes no override and does not veto another vhost's request. Repeated `true`
#   values emit `multipath` once per TCP socket. Requires Nginx 1.29.7 or newer with Multipath TCP support on Linux 5.6
#   or newer. Nginx also enables SO_REUSEPORT when adding or removing this option.
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
#   Optional IPv6 listen address in square brackets for the redirect server.
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
#   Referrer-Policy header value. `true` uses the module default, a string sets a vhost policy, and `false` disables the
#   managed header.
#
# @param restart_service
#   Notifies Nginx when this vhost file or its shared listener configuration changes if `true`. Shared listener changes
#   notify the service when at least one participating vhost enables notifications.
#
# @param reuseport
#   Requests shared `reuseport` on TCP and QUIC listeners. Repeated `true` values emit it once per socket. `false`
#   contributes no override and does not veto another vhost's request.
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
#   Space-separated Nginx `server_name` value. `undef` omits the directive and keeps the title fallback for
#   security.txt; TLS monitoring then reports an unassessable target.
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
#   Optional trust file for client-certificate and OCSP validation; it never replaces the certificate chain sent to
#   clients.
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
#   HSTS header value. `true` uses the module default, a string sets a vhost value, and `false` disables the managed
#   header.
#
# @param try_files
#   Root-location `try_files` behavior. `true` uses `$uri $uri/ =404`, a string supplies custom arguments, and `false`
#   omits the directive.
#
# @param x_content_type_options
#   X-Content-Type-Options header value. `true` uses `nosniff`, a string sets a vhost value, and `false` disables the
#   managed header.
#
# @param x_frame_options
#   X-Frame-Options header value. `true` uses `SAMEORIGIN`, a string sets a vhost value, and `false` disables the
#   managed header.
#
# @api public
define nginx::server (
  Optional[String]          $access_log                      = undef,
  Boolean                   $acme_enable                     = false,
  Boolean                   $allow_directories               = false,
  Integer                   $backlog                         = -1, # Global settings; -1: Disabled, 0: Kernel; >0: Custom value
  Optional[String]          $client_max_body_size            = undef,
  Variant[Boolean, String]  $content_security_policy         = true,
  Boolean                   $default_server                  = false,
  Array                     $directives                      = [],
  Optional[String]          $docroot                         = undef,
  Enum['present', 'absent'] $ensure                          = present,
  Optional[String]          $error_log                       = undef,
  Optional[Integer]         $fastcgi_read_timeout            = undef,
  Integer                   $fastopen                        = 0, # Global settings
  Boolean                   $http2_enable                    = true,
  Boolean                   $http3_enable                    = true,
  Boolean                   $http_enable                     = true,
  Boolean                   $http_ipv6                       = true,
  Integer                   $http_port                       = 80,
  Boolean                   $https_enable                    = false,
  Boolean                   $https_force                     = false,
  Boolean                   $https_ipv6                      = true,
  Integer                   $https_port                      = 443,
  Optional[String]          $ip                              = undef,
  Optional[String]          $ipv6                            = undef,
  Optional[String]          $keepalive_request_file          = undef,
  Array                     $location_directives             = [],
  Boolean                   $location_internal               = false,
  Array                     $locations                       = [],
  Boolean                   $monitoring_cert                 = true,
  Boolean                   $multipath                       = false, # Global settings
  Array                     $php_fpm_directives              = [],
  Boolean                   $php_fpm_enable                  = true,
  String                    $php_fpm_location                = '~* \.php$',
  String                    $php_fpm_location_inc            = '~* \.php.inc$',
  String                    $php_fpm_uri                     = 'unix:/run/php/php-fpm.sock',
  Optional[String]          $redirect_certificate            = undef,
  Optional[String]          $redirect_certificate_key        = undef,
  Optional[String]          $redirect_certificate_trusted    = undef,
  Optional[String]          $redirect_from                   = undef,
  Optional[String]          $redirect_http_port              = undef,
  Optional[String]          $redirect_https_port             = undef,
  Optional[String]          $redirect_ip                     = undef,
  Optional[String]          $redirect_ipv6                   = undef,
  Optional[Array]           $redirect_ssl_ciphers            = undef,
  Optional[Hash]            $redirect_ssl_conf_command       = undef,
  Optional[String]          $redirect_ssl_ocsp               = undef,
  Optional[String]          $redirect_ssl_protocols          = undef,
  Variant[Boolean, String]  $referrer_policy                 = true,
  Boolean                   $restart_service                 = true,
  Boolean                   $reuseport                       = false, # Global settings
  Optional[Array]           $securitytxt_contacts            = undef,
  Optional[Boolean]         $securitytxt_enable              = undef,
  Optional[String]          $securitytxt_encryption          = undef,
  Optional[Integer]         $securitytxt_expires_days        = undef,
  Optional[String]          $securitytxt_policy              = undef,
  Optional[Array]           $securitytxt_preferred_languages = undef,
  Optional[String]          $server_name                     = undef,
  Optional[Integer]         $ssl_buffer_size                 = undef,
  Optional[String]          $ssl_certificate                 = undef,
  Optional[String]          $ssl_certificate_key             = undef,
  Optional[String]          $ssl_certificate_trusted         = undef,
  Array                     $ssl_ciphers                     = [
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
  Hash                      $ssl_conf_command                = {
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
  Boolean                   $ssl_ocsp                        = false,
  Optional[String]          $ssl_protocols                   = undef,
  Optional[String]          $ssl_session_cache               = undef,
  Optional[String]          $ssl_session_timeout             = undef,
  Variant[Boolean, String]  $strict_transport_security       = true,
  Variant[Boolean, String]  $try_files                       = true,
  Variant[Boolean, String]  $x_content_type_options          = true,
  Variant[Boolean, String]  $x_frame_options                 = true,
) {
  # Require the Nginx parent before using its paths and defaults to manage the vhost.
  if (defined(Class['nginx'])) {
    # Share the owning resource path with the check instead of rebuilding it in a monitoring helper.
    $config_file = "${nginx::config}/${name}.conf"

    # Create security.txt file path
    $security_dir = "/etc/nginx/security/${name}"
    $securitytxt_file = "${security_dir}/security.txt"

    # Share the primary host identity between security.txt and certificate-check registration names.
    if ($server_name != undef and $server_name =~ /\S/) {
      # Use the first configured server name, including when names are separated by tabs or newlines.
      $server_name_primary = split(strip($server_name), '\s+')[0]
    } else {
      # Fall back to the resource title for labels and security.txt, never for certificate validation.
      $server_name_primary = $name
    }

    # Prefer explicit vhost contacts, then nginx-wide contacts, then monitoring mail.
    if ($securitytxt_contacts == undef) {
      # Use monitoring or hostname fallbacks only when no Nginx-wide contacts were supplied.
      if ($nginx::securitytxt_contacts == undef) {
        # Use the monitoring contact when available, otherwise derive the domain-local fallback.
        if ($nginx::monitoring_enable) {
          # basic_settings::monitoring::mail_to is an address, so add mailto: when needed.
          $securitytxt_contacts_correct = $basic_settings::monitoring::mail_to ? {
            /^(mailto:|https:\/\/|tel:)/ => [$basic_settings::monitoring::mail_to],
            default                     => ["mailto:${basic_settings::monitoring::mail_to}"],
          }
        } else {
          # Last resort: use the primary vhost name so the generated Contact is domain-local.
          $securitytxt_contacts_correct = ["mailto:info@${server_name_primary}"]
        }
      } else {
        # Inherit security.txt contacts from the Nginx class.
        $securitytxt_contacts_correct = $nginx::securitytxt_contacts
      }
    } else {
      # Use the server's explicit security.txt contacts.
      $securitytxt_contacts_correct = $securitytxt_contacts
    }

    # Let each vhost opt out, otherwise follow the nginx-wide default.
    if ($securitytxt_enable != undef) {
      # Preserve the server's explicit security.txt enablement.
      $securitytxt_enable_correct = $securitytxt_enable
    } else {
      # Inherit security.txt enablement from the Nginx class.
      $securitytxt_enable_correct = $nginx::securitytxt_enable
    }

    # Optional fields can be set per vhost or inherited from nginx.
    if ($securitytxt_policy != undef) {
      # Use the server's explicit security policy URL.
      $securitytxt_policy_correct = $securitytxt_policy
    } else {
      # Inherit the security policy URL from the Nginx class.
      $securitytxt_policy_correct = $nginx::securitytxt_policy
    }

    # Prefer a vhost-specific Encryption URL; otherwise inherit the nginx-wide default.
    if ($securitytxt_encryption != undef) {
      # Use the server's explicit security.txt encryption reference.
      $securitytxt_encryption_correct = $securitytxt_encryption
    } else {
      # Inherit the security.txt encryption reference from the Nginx class.
      $securitytxt_encryption_correct = $nginx::securitytxt_encryption
    }

    # Prefer vhost-specific languages; otherwise use the nginx-wide language list.
    if ($securitytxt_preferred_languages != undef) {
      # Use the server's explicit security.txt language preferences.
      $securitytxt_preferred_languages_correct = $securitytxt_preferred_languages
    } else {
      # Inherit security.txt language preferences from the Nginx class.
      $securitytxt_preferred_languages_correct = $nginx::securitytxt_preferred_languages
    }

    # Prefer a vhost-specific expiry window; otherwise use the nginx-wide value.
    if ($securitytxt_expires_days != undef) {
      # Use the server's explicit security.txt expiry interval.
      $securitytxt_expires_days_correct = $securitytxt_expires_days
    } else {
      # Inherit the security.txt expiry interval from the Nginx class.
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
      # Normalize the first proxy target into the backend security.txt URL.
      $securitytxt_proxy_pass_target      = regsubst(
        String($securitytxt_proxy_pass_directives[0]),
        '^\s*proxy_pass\s+([^;\s#]+).*$',
        '\1'
      )
      $securitytxt_proxy_pass_base        = regsubst($securitytxt_proxy_pass_target, '/+$', '')
      $securitytxt_proxy_pass_securitytxt = "${securitytxt_proxy_pass_base}/.well-known/security.txt"

      # Enable backend routing now that a proxy target is available.
      $securitytxt_proxy_enable           = true
    } else {
      # Leave backend security.txt routing disabled when no proxy target is available.
      $securitytxt_proxy_pass_target      = undef
      $securitytxt_proxy_pass_base        = undef
      $securitytxt_proxy_pass_securitytxt = undef
      $securitytxt_proxy_enable           = false
    }

    # Preferred-Languages is optional; an empty array simply omits the field.
    if ($securitytxt_preferred_languages_correct != undef and !empty($securitytxt_preferred_languages_correct)) {
      # Format language preferences as the comma-separated security.txt field.
      $securitytxt_languages = join($securitytxt_preferred_languages_correct, ',')
    } else {
      # Omit language preferences when none are configured.
      $securitytxt_languages = ''
    }

    # Invalid Contact values suppress the managed file instead of failing the catalog.
    $securitytxt_invalid_contacts = filter($securitytxt_contacts_correct) |$securitytxt_contact_value| {
      String($securitytxt_contact_value) !~ /^(mailto:|https:\/\/|tel:)/
    }

    # Invalid security.txt input disables the managed fallback instead of failing the catalog.
    $securitytxt_active = (
      $securitytxt_enable_correct
      and $ensure == present
      and ($securitytxt_expires_days_correct > 0)
      and !empty($securitytxt_contacts_correct)
      and empty($securitytxt_invalid_contacts)
    )

    # security.txt canonical always points at the standard well-known URL for this vhost.
    $securitytxt_canonical_correct = "https://${server_name_primary}/.well-known/security.txt"

    # Only calculate Expires after validating the configured day count.
    if ($securitytxt_expires_days_correct > 0) {
      # Generate the security.txt expiry timestamp from the configured validity interval.
      $securitytxt_expires = (Timestamp() + Timespan("${securitytxt_expires_days_correct}-00:00:00")).strftime('%Y-%m-%dT00:00:00Z')
    } else {
      # Omit the security.txt expiry field when no positive validity interval is selected.
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

    # Resolve address-family policy and optional kernel-backed socket settings once for this vhost.
    if (defined(Class['basic_settings::kernel'])) {
      # Use IPv6 listeners only when kernel policy permits them.
      $http_ipv6_correct = $http_ipv6 and $basic_settings::kernel::ip_version_v6
      $https_ipv6_correct = $https_ipv6 and $basic_settings::kernel::ip_version_v6

      # A zero backlog inherits the kernel limit; Fast Open requires the kernel's client/server setting.
      $backlog_value = $backlog ? {
        0       => $basic_settings::kernel::connection_max,
        default => $backlog > 0 ? { true => $backlog, default => undef },
      }
      $fastopen_value = ($basic_settings::kernel::tcp_fastopen == 3 and $fastopen > 0) ? {
        true    => $fastopen,
        default => undef,
      }
    } else {
      # Without managed kernel policy, honor the vhost's address-family settings.
      $http_ipv6_correct = $http_ipv6
      $https_ipv6_correct = $https_ipv6

      # Without kernel configuration only an explicitly positive backlog can contribute an override.
      $backlog_value = $backlog > 0 ? { true => $backlog, default => undef }
      $fastopen_value = undef
    }

    # Check if HTTP/2 or HTTP/3 is allowed
    if ($https_enable and $ssl_certificate != undef and $ssl_certificate_key != undef) {
      # Honor the HTTP/2 setting for the certificate-backed HTTPS listener.
      $http2_active = $http2_enable

      # Enable HTTP/3 only when a selected protocol setting permits TLS 1.3.
      if ($ssl_protocols != undef and $ssl_protocols =~ 'TLSv1.3') {
        # Honor the HTTP/3 setting when the server's protocol list includes TLS 1.3.
        $http3_active = $http3_enable
      } elsif ($nginx::ssl_protocols =~ 'TLSv1.3') {
        # Honor the HTTP/3 setting when the inherited protocol list includes TLS 1.3.
        $http3_active = $http3_enable
      } else {
        # Disable HTTP/3 when neither selected protocol list permits TLS 1.3.
        $http3_active = false
      }

      # Check if redirect_certificate is not given
      if ($redirect_certificate != undef and $redirect_certificate_key != undef) {
        # Use the dedicated certificate pair supplied for redirect listeners.
        $redirect_certificate_correct = $redirect_certificate
        $redirect_certificate_key_correct = $redirect_certificate_key
      } else {
        # Reuse the primary certificate pair when no complete redirect pair is supplied.
        $redirect_certificate_correct = $ssl_certificate
        $redirect_certificate_key_correct = $ssl_certificate_key
      }
    } else {
      # Disable certificate-dependent protocols and redirect certificates without a usable HTTPS listener.
      $http2_active = false
      $http3_active = false
      $redirect_certificate_correct = undef
      $redirect_certificate_key_correct = undef
    }

    # Split server_name from by space, we need only the first in template to use as a redirect
    if ($redirect_from and $redirect_from != '') {
      # Redirect requests to the first configured canonical server name.
      $redirect_to = split($server_name, ' ')[0]
    }

    # Set IPv4
    if ($redirect_ip == undef) {
      # Reuse the main IPv4 listen address for the redirect listener.
      $redirect_ip_correct = $ip
    } else {
      # Use the explicit IPv4 redirect listen address.
      $redirect_ip_correct = $redirect_ip
    }

    # Set IPv6
    if ($redirect_ipv6 == undef) {
      # Reuse the main IPv6 listen address for the redirect listener.
      $redirect_ipv6_correct = $ipv6
    } else {
      # Use the explicit IPv6 redirect listen address.
      $redirect_ipv6_correct = $redirect_ipv6
    }

    # Set HTTP port
    if ($redirect_http_port == undef) {
      # Reuse the primary HTTP port for the redirect listener.
      $redirect_http_port_correct = $http_port
    } else {
      # Use the explicit HTTP redirect port.
      $redirect_http_port_correct = $redirect_http_port
    }

    # Set HTTP port
    if ($redirect_https_port == undef) {
      # Reuse the primary HTTPS port for the redirect listener.
      $redirect_https_port_correct = $https_port
    } else {
      # Use the explicit HTTPS redirect port.
      $redirect_https_port_correct = $redirect_https_port
    }

    # Set SSL protocols
    if ($redirect_ssl_protocols == undef) {
      # Reuse the primary TLS protocol selection for redirects.
      $redirect_ssl_protocols_correct = $ssl_protocols
    } else {
      # Use the explicit TLS protocol selection for redirects.
      $redirect_ssl_protocols_correct = $redirect_ssl_protocols
    }

    # Set SSL conf
    if ($redirect_ssl_conf_command == undef) {
      # Reuse the primary OpenSSL configuration commands for redirects.
      $redirect_ssl_conf_command_correct = $ssl_conf_command
    } else {
      # Use the explicit OpenSSL configuration commands for redirects.
      $redirect_ssl_conf_command_correct = $redirect_ssl_conf_command
    }

    # Set SSL ciphers
    $ssl_ciphers_correct = join($ssl_ciphers, ':')

    # Inherit the main vhost ciphers unless redirect-specific ciphers were supplied.
    if ($redirect_ssl_ciphers == undef) {
      # Reuse the resolved primary TLS cipher list for redirects.
      $redirect_ssl_ciphers_correct = $ssl_ciphers_correct
    } else {
      # Format the explicit redirect cipher list for Nginx.
      $redirect_ssl_ciphers_correct = join($redirect_ssl_ciphers, ':')
    }

    # Set SSL ocsp
    if ($redirect_ssl_ocsp == undef) {
      # Reuse the primary OCSP setting for redirects.
      $redirect_ssl_ocsp_correct = $ssl_ocsp
    } else {
      # Use the explicit OCSP setting for redirects.
      $redirect_ssl_ocsp_correct = $redirect_ssl_ocsp
    }

    # Preserve service notifications while sharing the configuration resource with monitoring.
    $config_ensure = $ensure ? { present => file, default => absent }
    $config_notify = $restart_service ? { true => Service['nginx'], default => undef }

    # Configure listeners and register certificate checks only for present vhosts.
    if ($ensure == present) {
      # Realize host-wide QUIC settings once, even when several active vhosts share them.
      if ($http3_active) {
        realize(File['nginx_quic'])

        # Reuse the parent service integration only when systemd is managed.
        if ($nginx::systemd_enable) {
          realize(Basic_settings::Systemd_drop_in['nginx_quic'])
        }
      }

      # Disabled defaults do not veto another vhost's override; UDP supports only reuseport from these options.
      $listen_tcp_settings = {
        'backlog'   => $backlog_value,
        'fastopen'  => $fastopen_value,
        'multipath' => $multipath ? { true => true, default => undef },
        'reuseport' => $reuseport ? { true => true, default => undef },
      }
      $listen_udp_settings = { 'reuseport' => $listen_tcp_settings['reuseport'] }

      # Default-server selection remains specific to each vhost and transport.
      $listen_default_flags = $default_server ? { true => ['default'], default => [] }
      $listen_https_flags = $http3_active ? {
        true    => [concat(['quic'], $listen_default_flags), ['ssl']],
        default => [concat(['ssl'], $listen_default_flags)],
      }

      # Redirects share protocol settings without claiming the default-server role.
      $listen_redirect_https_flags = $http3_active ? { true => [['quic'], ['ssl']], default => [['ssl']] }

      # Keep the existing primary and redirect listener enablement, addresses and ports together.
      $listen_groups = {
        'http' => {
          'enable' => $http_enable,
          'ipv6_enable' => $http_ipv6_correct,
          'ip' => $ip, 'ipv6' => $ipv6, 'port' => $http_port,
          'flags' => [$listen_default_flags],
        },
        'https' => {
          'enable' => $https_enable,
          'ipv6_enable' => $https_ipv6_correct,
          'ip' => $ip, 'ipv6' => $ipv6, 'port' => $https_port,
          'flags' => $listen_https_flags,
        },
        'redirect_http' => {
          'enable' => $redirect_from != undef,
          'ipv6_enable' => $http_ipv6_correct,
          'ip' => $redirect_ip_correct, 'ipv6' => $redirect_ipv6_correct, 'port' => $redirect_http_port_correct,
          'flags' => [[]],
        },
        'redirect_https' => {
          'enable' => $redirect_from != undef and $https_enable,
          'ipv6_enable' => $https_ipv6_correct,
          'ip' => $redirect_ip_correct, 'ipv6' => $redirect_ipv6_correct, 'port' => $redirect_https_port_correct,
          'flags' => $listen_redirect_https_flags,
        },
      }
      $listen_directives = Hash($listen_groups.map |$group, $listener| {
        # Register only listeners whose server block will be rendered.
        if ($listener['enable']) {
          # An explicit IPv6 address selects IPv6 only; otherwise IPv6 enablement retains the IPv4 wildcard too.
          if ($listener['ipv6_enable']) {
            # Match the template's existing dual-stack selection.
            $addresses = $listener['ipv6'] ? { undef => ['[::]', undef], default => [$listener['ipv6']] }
          } else {
            # Use the configured IPv4 address or its wildcard default.
            $addresses = [$listener['ip']]
          }

          # Prepare every directive here so the vhost template only renders the resulting text.
          $directives = flatten($addresses.map |$address| {
            # Use the default IPv4 wildcard only when no address is configured.
            $address_correct = $address ? { undef => '0.0.0.0', default => $address }
            $socket_address = "${address_correct}:${listener['port']}"
            $listener['flags'].map |$flags| {
              # TCP and QUIC on the same address and port have distinct identities and shared files.
              $transport = 'quic' in $flags ? { true => 'udp', default => 'tcp' }
              $socket = "${transport} ${socket_address}"
              $path = "${nginx::config}/listen-${stdlib::sha256($socket)}.inc"
              $primary = !defined(Concat[$path])

              # Keep protocol selection and the shared directive's complete address/flags out of templates.
              $settings = $transport ? { 'udp' => $listen_udp_settings, default => $listen_tcp_settings }
              $listen = join(concat([$socket_address], $flags), ' ')

              # The first vhost for this socket owns its snippet; later vhosts contribute options to the same file.
              if $primary {
                concat { $path:
                  owner   => 'root',
                  group   => 'root',
                  mode    => '0600',
                  require => [Package['nginx'], File[$nginx::config]],
                }

                # Keep the managed header and listener flags before the independently collected socket options.
                concat::fragment { "nginx_listen_${socket}_header":
                  target  => $path,
                  content => template('nginx/listen.conf'),
                  order   => '01',
                }

                # Terminate the directive only after every shared option fragment.
                concat::fragment { "nginx_listen_${socket}_footer":
                  target  => $path,
                  content => ";\n",
                  order   => '99',
                }
              }

              # Install the complete shared directive before any participating vhost can trigger a reload.
              Concat[$path] -> File[$config_file]

              # Any participating vhost can request reloads, including when the first vhost opts out.
              if $restart_service {
                Concat[$path] ~> Service['nginx']
              }

              # Register only effective overrides; repeated equal values contribute one fragment per socket.
              $settings.each |$setting, $value| {
                # A missing override neither contributes a fragment nor conflicts with an enabled option.
                if $value != undef {
                  # Socket identity keeps fragments shared across vhosts, independently of evaluation order.
                  $fragment = "nginx_listen_${socket}_${setting}"
                  $content = $value ? { true => " ${setting}", default => " ${setting}=${value}" }

                  # Reuse identical fragments; conflicting values fail with the socket and setting in the resource title.
                  ensure_resource('concat::fragment', $fragment, {
                    'target'  => $path,
                    'content' => $content,
                    'order'   => "50-${setting}",
                  })
                }
              }

              # Include shared options once; all other server blocks retain their own address and flags.
              $primary ? {
                true    => "include ${path};",
                default => "listen ${listen};",
              }
            }
          })
          [$group, $directives]
        } else {
          [$group, []]
        }
      })

      # All listener decisions are complete before rendering the vhost in one template.
      $config_content = template('nginx/server.conf')

      # Register checks only for active TLS vhosts; concat removes omitted registrations from customchecks.ini.
      if ($monitoring_cert and $https_enable
        and $ssl_certificate != undef and $ssl_certificate != ''
        and $ssl_certificate_key != undef and $ssl_certificate_key != ''
        and $nginx::monitoring_enable and $basic_settings::monitoring::package != 'none') {
        # Register the main HTTPS identity using the configuration path owned by this vhost.
        nginx::monitoring_cert { "${name}/main":
          config_file       => $config_file,
          registration_name => "${server_name_primary}/main",
          server_name       => $server_name,
        }

        # Register a configured TLS redirect separately so its certificate cannot replace the main target's assessment.
        if ($redirect_from != undef and $redirect_from != ''
          and $redirect_certificate_correct != '' and $redirect_certificate_key_correct != '') {
          nginx::monitoring_cert { "${name}/redirect":
            config_file       => $config_file,
            registration_name => "${server_name_primary}/redirect",
            server_name       => $redirect_from,
          }
        }
      }
    } else {
      # File removal does not need content or shared socket registrations.
      $config_content = undef
    }

    # Share one File declaration for present and absent vhosts and their monitoring/cleanup dependencies.
    file { $config_file:
      ensure  => $config_ensure,
      content => $config_content,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      notify  => $config_notify,
      require => [Package['nginx'], File[$nginx::config]],
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
        subscribe   => File[$config_file],
        require     => Package['coreutils'],
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
