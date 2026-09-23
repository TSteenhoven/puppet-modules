# @summary Publishes one Docker application endpoint through the shared Nginx proxy configuration.
#
# Declare docker and nginx first. This defined type owns only the vhost; callers own the Compose deployment and
# order this endpoint after it with require. Multiple endpoints can therefore share one Compose stack.
# The title determines the docker_compose_<title> vhost and log names. Removing the resource lets nginx's
# managed configuration directory retire the vhost.
#
# @example Publish a second HTTPS endpoint of an existing Compose project
#   include docker
#
#   # Provide the webserver for this endpoint.
#   include nginx
#
#   # The deployment can order this endpoint after its existing Compose resource.
#   docker::proxy { 'example_admin':
#     proxy_port          => 9443,
#     server_name         => 'admin.example.org',
#     ssl_certificate     => '/etc/letsencrypt/live/admin.example.org/fullchain.pem',
#     ssl_certificate_key => '/etc/letsencrypt/live/admin.example.org/privkey.pem',
#   }
#
# @param proxy_port
#   Local upstream port used by Nginx for `proxy_pass`.
#
# @param server_name
#   Public Nginx `server_name` value for the generated vhost.
#
# @param client_max_body_size
#   Optional `client_max_body_size` value for the generated Nginx vhost.
#
# @param content_security_policy
#   CSP header value passed to `nginx::server`.
#
# @param http2_enable
#   Enables HTTP/2 for the public HTTPS listener when certificates are present.
#
# @param http3_enable
#   Enables HTTP/3 for the public HTTPS listener when certificates are present.
#
# @param http_enable
#   Creates a public HTTP listener.
#
# @param https_force
#   Redirects public HTTP to HTTPS when public certificates are configured.
#
# @param proxy_extra_directives
#   Additional directives appended to the generated Nginx proxy location.
#
# @param proxy_host
#   Local upstream host used by Nginx for `proxy_pass`. The default is `127.0.0.1`.
#
# @param proxy_read_timeout
#   Nginx proxy read timeout for long-lived requests and websocket sessions.
#
# @param proxy_scheme
#   Upstream scheme used by Nginx. The default is `https` so local proxy traffic is encrypted unless the caller
#   explicitly opts out with `http`.
#
# @param proxy_ssl_trusted_certificate
#   Optional CA bundle path for verifying HTTPS upstream certificates.
#
# @param proxy_ssl_verify
#   Verifies HTTPS upstream certificates when `true`. The default is `false` so locally encrypted upstreams with
#   self-signed certificates keep working.
#
# @param proxy_websocket
#   Adds common websocket upgrade directives when `true`.
#
# @param referrer_policy
#   Referrer-Policy header value passed to `nginx::server`.
#
# @param ssl_certificate
#   Public TLS certificate path for the generated Nginx vhost.
#
# @param ssl_certificate_key
#   Public TLS private key path for the generated Nginx vhost.
#
# @param ssl_certificate_trusted
#   Optional trusted certificate path for public OCSP configuration.
#
# @param strict_transport_security
#   HSTS header value passed to `nginx::server`.
#
# @param x_content_type_options
#   X-Content-Type-Options header value passed to `nginx::server`.
#
# @param x_frame_options
#   X-Frame-Options header value passed to `nginx::server`.
#
# @api public
define docker::proxy (
  Integer[1, 65535]        $proxy_port,
  String                   $server_name,
  Optional[String]         $client_max_body_size          = undef,
  Variant[Boolean, String] $content_security_policy       = true,
  Boolean                  $http2_enable                  = true,
  Boolean                  $http3_enable                  = true,
  Boolean                  $http_enable                   = true,
  Boolean                  $https_force                   = true,
  Array[String]            $proxy_extra_directives        = [],
  Pattern[/\A[^\r\n]+\z/]  $proxy_host                    = '127.0.0.1',
  Pattern[/\A[^\r\n]+\z/]  $proxy_read_timeout            = '86400',
  Enum['http', 'https']    $proxy_scheme                  = 'https',
  Optional[String]         $proxy_ssl_trusted_certificate = undef,
  Boolean                  $proxy_ssl_verify              = false,
  Boolean                  $proxy_websocket               = true,
  Variant[Boolean, String] $referrer_policy               = true,
  Optional[String]         $ssl_certificate               = undef,
  Optional[String]         $ssl_certificate_key           = undef,
  Optional[String]         $ssl_certificate_trusted       = undef,
  Variant[Boolean, String] $strict_transport_security     = true,
  Variant[Boolean, String] $x_content_type_options        = true,
  Variant[Boolean, String] $x_frame_options               = true,
) {
  # Endpoint configuration needs the same parent classes as the Compose proxy wrapper.
  if (defined(Class['nginx']) and defined(Class['docker'])) {
    # Construct the proxy upstream URL for use in the generated Nginx configuration.
    $proxy_upstream = "${proxy_scheme}://${proxy_host}:${proxy_port}"

    # Determine correct https_force value based on whether SSL is configured for the public vhost.
    $ssl_enable = ($ssl_certificate != undef and $ssl_certificate_key != undef)
    $https_force_correct = $ssl_enable ? {
      true    => $https_force,
      default => false,
    }

    # Determine the correct proxy_ssl_verify directive value based on the boolean parameter.
    $proxy_ssl_verify_value = $proxy_ssl_verify ? {
      true    => 'on',
      default => 'off',
    }
    $proxy_ssl_verify_directives = $proxy_scheme ? {
      'https' => ["proxy_ssl_verify ${proxy_ssl_verify_value};"],
      default => [],
    }

    # Determine the correct proxy_ssl_trusted_certificate directive based on the presence of the parameter and the upstream scheme.
    if ($proxy_scheme == 'https' and $proxy_ssl_trusted_certificate != undef) {
      # Pass the supplied trust store to Nginx for HTTPS upstream verification.
      $proxy_ssl_trusted_directives = [
        "proxy_ssl_trusted_certificate ${proxy_ssl_trusted_certificate};",
      ]
    } else {
      # Omit upstream trust-store directives when no HTTPS trust store is selected.
      $proxy_ssl_trusted_directives = []
    }

    # Determine websocket directives based on the boolean parameter.
    $proxy_websocket_directives = $proxy_websocket ? {
      true    => [
        'proxy_http_version 1.1;',
        'proxy_set_header Upgrade $http_upgrade;',
        'proxy_set_header Connection "Upgrade";',
      ],
      default => [],
    }

    # Base proxy directives are always included; SSL and websocket directives are conditional.
    $location_directives_base = [
      "proxy_pass ${proxy_upstream};",
      'proxy_set_header Host $host;',
      'proxy_set_header X-Real-IP $remote_addr;',
      'proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;',
      'proxy_set_header X-Forwarded-Host $host;',
      'proxy_set_header X-Forwarded-Proto $scheme;',
      "proxy_read_timeout ${proxy_read_timeout};",
    ]

    # Append optional proxy directives in their effective Nginx order.
    $location_directives = concat(
      $location_directives_base,
      $proxy_ssl_verify_directives,
      $proxy_ssl_trusted_directives,
      $proxy_websocket_directives,
      $proxy_extra_directives,
    )

    # Keep access and error diagnostics in separate logs for this proxy.
    $proxy_access_log = "/var/log/nginx/docker_compose_${name}_access.log combined buffer=32k flush=1m"
    $proxy_error_log = "/var/log/nginx/docker_compose_${name}_error.log"

    # Publish the Compose stack with the prepared proxy settings.
    nginx::server { "docker_compose_${name}":
      access_log                => $proxy_access_log,
      client_max_body_size      => $client_max_body_size,
      content_security_policy   => $content_security_policy,
      docroot                   => undef,
      error_log                 => $proxy_error_log,
      http2_enable              => $http2_enable,
      http3_enable              => $http3_enable,
      http_enable               => $http_enable,
      https_enable              => $ssl_enable,
      https_force               => $https_force_correct,
      location_directives       => $location_directives,
      php_fpm_enable            => false,
      referrer_policy           => $referrer_policy,
      server_name               => $server_name,
      ssl_certificate           => $ssl_certificate,
      ssl_certificate_key       => $ssl_certificate_key,
      ssl_certificate_trusted   => $ssl_certificate_trusted,
      ssl_ocsp                  => $ssl_enable,
      ssl_session_cache         => 'shared:SSL:10m',
      ssl_session_timeout       => '10',
      strict_transport_security => $strict_transport_security,
      try_files                 => false,
      x_content_type_options    => $x_content_type_options,
      x_frame_options           => $x_frame_options,
    }
  } else {
    fail('docker::proxy requires the docker and nginx classes before creating a reverse proxy vhost.')
  }
}
