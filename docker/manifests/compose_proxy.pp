# @summary Deploys one Docker Compose project behind an Nginx reverse proxy.
#
# This defined type wraps `docker::compose` and adds an `nginx::server` vhost for applications that should be reachable
# through Nginx. It delegates endpoint configuration to docker::proxy so additional endpoints can use the same proxy
# behavior without declaring a second stack. Declare docker and nginx before using this defined type directly.
#
# @example Proxy a Compose stack over local HTTPS without validating the upstream certificate
#   class { 'docker': }
#
#   # Provide the webserver that terminates public TLS connections.
#   class { 'nginx': }
#
#   # Connect the Compose application to its public Nginx endpoint.
#   docker::compose_proxy { 'example':
#     compose_source => 'puppet:///modules/profile/example/docker-compose.yml',
#     proxy_port     => 9443,
#     server_name    => 'example.org',
#   }
#
# @param proxy_port
#   Local upstream port used by Nginx for `proxy_pass`.
#
# @param server_name
#   Public Nginx `server_name` value for the generated vhost.
#
# @param backup_database_on_calendar
#   Optional schedule override. Undef inherits the daily 05:00 schedule from docker::compose.
#
# @param backup_database_retention_days
#   Optional retention override. Undef inherits seven days from docker::compose.
#
# @param backup_database_type
#   Optional database action passed to docker::compose; undef disables database backups.
#
# @param backup_service
#   Compose service name passed to docker::compose. Defaults to undef; required for enabled database backups.
#
# @param client_max_body_size
#   Optional `client_max_body_size` value for the generated Nginx vhost.
#
# @param compose_checksum
#   Optional SHA256 checksum for compose_source, unavailable with compose_content. Defaults to undef.
#
# @param compose_content
#   Optional rendered Compose content passed to docker::compose; defaults to undef. Supply exactly one of
#   compose_content and compose_source for a present stack.
#
# @param compose_source
#   Optional Compose file source passed to docker::compose; defaults to undef. Must start with https://, file:///,
#   or puppet:///; excludes compose_content.
#
# @param content_security_policy
#   CSP header value passed to `nginx::server`.
#
# @param ensure
#   Controls the Compose project state. The Nginx vhost is declared when this is `present`; when this is `absent`, only
#   the Compose project removal is delegated.
#
# @param env_content
#   Optional `.env` content passed to `docker::compose`.
#
# @param env_source
#   Optional `.env` source passed to `docker::compose`.
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
# @param monitoring_detail_limit
#   Maximum number of diagnostic characters emitted before the Compose monitoring `Interpretation:` section.
#
# @param monitoring_expected_exited
#   Container names that are allowed to be exited without making the stack critical.
#
# @param monitoring_health_required
#   Container names that must have a healthy Docker health state.
#
# @param monitoring_interval
#   Monitoring interval in seconds for the Compose stack check.
#
# @param monitoring_orphan_critical
#   Treats orphaned Compose containers as critical when `true`.
#
# @param monitoring_profiles
#   Compose profiles passed to the monitoring check.
#
# @param monitoring_starting_grace
#   Grace period in seconds before starting containers are considered a problem.
#
# @param monitoring_timeout
#   Timeout in seconds for the Compose stack monitoring check.
#
# @param project_directories
#   Optional single-segment directories passed to `docker::compose` for creation below the Compose project directory.
#   Values may override owner, group, and mode.
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
# @param pull
#   Stack-wide image pull policy passed unchanged to `docker::compose`, default missing. Accepts always, missing and
#   never; see `docker::compose` for startup prerequisites and update behavior.
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
# @param target
#   `basic_settings::systemd` target suffix for the generated Compose service.
#
# @param x_content_type_options
#   X-Content-Type-Options header value passed to `nginx::server`.
#
# @param x_frame_options
#   X-Frame-Options header value passed to `nginx::server`.
#
# @api public
define docker::compose_proxy (
  Integer[1, 65535]                            $proxy_port,
  String                                       $server_name,
  Optional[Pattern[/\A[^\r\n]+\z/]]            $backup_database_on_calendar    = undef,
  Optional[Integer[1]]                         $backup_database_retention_days = undef,
  Optional[Enum['postgresql']]                 $backup_database_type           = undef,
  Optional[Pattern[/\A[A-Za-z0-9_.-]+\z/]]     $backup_service                 = undef,
  Optional[String]                             $client_max_body_size           = undef,
  Optional[Pattern[/\A[0-9a-fA-F]{64}\z/]]     $compose_checksum               = undef,
  Optional[String]                             $compose_content                = undef,
  Optional[String]                             $compose_source                 = undef,
  Variant[Boolean, String]                     $content_security_policy        = true,
  Enum['present', 'absent']                    $ensure                         = present,
  Optional[Variant[String, Sensitive[String]]] $env_content                    = undef,
  Optional[String]                             $env_source                     = undef,
  Boolean                                      $http2_enable                   = true,
  Boolean                                      $http3_enable                   = true,
  Boolean                                      $http_enable                    = true,
  Boolean                                      $https_force                    = true,
  Integer                                      $monitoring_detail_limit        = 6000,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]        $monitoring_expected_exited     = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]        $monitoring_health_required     = [],
  Integer                                      $monitoring_interval            = 300,
  Boolean                                      $monitoring_orphan_critical     = false,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]]        $monitoring_profiles            = [],
  Integer                                      $monitoring_starting_grace      = 300,
  Integer                                      $monitoring_timeout             = 60,
  Hash[Pattern[/\A[A-Za-z0-9_.-]+\z/], Struct[{
        Optional[owner] => String[1],
        Optional[group] => String[1],
        Optional[mode]  => Pattern[/\A[0-7]{4}\z/],
  }]]                                          $project_directories            = {},
  Array[String]                                $proxy_extra_directives         = [],
  Pattern[/\A[^\r\n]+\z/]                      $proxy_host                     = '127.0.0.1',
  Pattern[/\A[^\r\n]+\z/]                      $proxy_read_timeout             = '86400',
  Enum['http', 'https']                        $proxy_scheme                   = 'https',
  Optional[String]                             $proxy_ssl_trusted_certificate  = undef,
  Boolean                                      $proxy_ssl_verify               = false,
  Boolean                                      $proxy_websocket                = true,
  Enum['always', 'missing', 'never']           $pull                           = 'missing',
  Variant[Boolean, String]                     $referrer_policy                = true,
  Optional[String]                             $ssl_certificate                = undef,
  Optional[String]                             $ssl_certificate_key            = undef,
  Optional[String]                             $ssl_certificate_trusted        = undef,
  Variant[Boolean, String]                     $strict_transport_security      = true,
  String                                       $target                         = 'services',
  Variant[Boolean, String]                     $x_content_type_options         = true,
  Variant[Boolean, String]                     $x_frame_options                = true,
) {
  # The proxy composes resources owned by both parent classes and orders the stack after Docker.
  if (defined(Class['nginx']) and defined(Class['docker'])) {
    # Create the Compose stack
    docker::compose { $name:
      ensure                         => $ensure,
      backup_database_on_calendar    => $backup_database_on_calendar,
      backup_database_retention_days => $backup_database_retention_days,
      backup_database_type           => $backup_database_type,
      backup_service                 => $backup_service,
      compose_checksum               => $compose_checksum,
      compose_content                => $compose_content,
      compose_source                 => $compose_source,
      env_content                    => $env_content,
      env_source                     => $env_source,
      monitoring_detail_limit        => $monitoring_detail_limit,
      monitoring_expected_exited     => $monitoring_expected_exited,
      monitoring_health_required     => $monitoring_health_required,
      monitoring_interval            => $monitoring_interval,
      monitoring_orphan_critical     => $monitoring_orphan_critical,
      monitoring_profiles            => $monitoring_profiles,
      monitoring_starting_grace      => $monitoring_starting_grace,
      monitoring_timeout             => $monitoring_timeout,
      project_directories            => $project_directories,
      pull                           => $pull,
      target                         => $target,
      require                        => Class['docker'],
    }

    # Create the public proxy only for deployed stacks.
    if ($ensure == present) {
      docker::proxy { $name:
        proxy_port                    => $proxy_port,
        server_name                   => $server_name,
        client_max_body_size          => $client_max_body_size,
        content_security_policy       => $content_security_policy,
        http2_enable                  => $http2_enable,
        http3_enable                  => $http3_enable,
        http_enable                   => $http_enable,
        https_force                   => $https_force,
        proxy_extra_directives        => $proxy_extra_directives,
        proxy_host                    => $proxy_host,
        proxy_read_timeout            => $proxy_read_timeout,
        proxy_scheme                  => $proxy_scheme,
        proxy_ssl_trusted_certificate => $proxy_ssl_trusted_certificate,
        proxy_ssl_verify              => $proxy_ssl_verify,
        proxy_websocket               => $proxy_websocket,
        referrer_policy               => $referrer_policy,
        ssl_certificate               => $ssl_certificate,
        ssl_certificate_key           => $ssl_certificate_key,
        ssl_certificate_trusted       => $ssl_certificate_trusted,
        strict_transport_security     => $strict_transport_security,
        x_content_type_options        => $x_content_type_options,
        x_frame_options               => $x_frame_options,
        require                       => Docker::Compose[$name],
      }
    }
  } else {
    fail('docker::compose_proxy requires the docker and nginx classes before composing the stack and reverse proxy vhost.')
  }
}
