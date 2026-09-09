# @summary Deploys the bundled Twenty Docker Compose stack.
#
# This defined type deploys the module-shipped `docker/files/twenty.yaml` Compose file.
# Declare `docker` before using it.
# lint:ignore:140chars
# The resource title becomes the Compose project name, so multiple Twenty stacks can be managed on the same host when ports and public names do not conflict.
# When `server_name` is set, declare `nginx` as well so `docker::compose_proxy` can add the reverse proxy; otherwise the defined type declares `docker::compose` directly.
# lint:endignore
# The generated `SERVER_URL` uses `scheme` with the first `server_name`, or `host` when `server_name` is unset.
#
# @example Deploy Twenty with generated `.env` content
#   class { 'docker': }
#
#   docker::twenty { 'twenty':
#     database_password    => Sensitive('replace-with-secret'),
#     host                 => 'twenty.example.org',
#     secret_key           => Sensitive('replace-with-secret'),
#   }
#
# @example Deploy Twenty behind Nginx
#   class { 'docker': }
#   class { 'nginx': }
#
#   docker::twenty { 'twenty':
#     database_password    => Sensitive('replace-with-secret'),
#     secret_key           => Sensitive('replace-with-secret'),
#     server_name          => 'twenty.example.org',
#     ssl_certificate      => '/etc/letsencrypt/live/twenty.example.org/fullchain.pem',
#     ssl_certificate_key  => '/etc/letsencrypt/live/twenty.example.org/privkey.pem',
#   }
#
# @param database_password
#   PostgreSQL password written as `PG_DATABASE_PASSWORD`.
#
# @param secret_key
#   Secret key written as `ENCRYPTION_KEY`.
#
# @param database_host
#   PostgreSQL host written as `PG_DATABASE_HOST`.
#
# @param database_port
#   PostgreSQL port written as `PG_DATABASE_PORT`.
#
# @param database_user
#   PostgreSQL user written as `PG_DATABASE_USER`.
#
# @param ensure
#   Controls whether the Twenty Compose project directory and service are present or absent.
#
# @param host
#   Local Twenty upstream host used by Nginx when `server_name` is set.
#   When `server_name` is unset, this is also used to derive `SERVER_URL`.
#   The default is `127.0.0.1`.
#
# @param image_tag
#   Docker image tag written as `TAG`.
#
# @param monitoring_detail_limit
#   Maximum number of diagnostic characters emitted before the Compose monitoring `Interpretation:` section.
#
# @param monitoring_expected_exited
#   Container names that are allowed to be exited without making the stack critical, such as one-shot migration containers.
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
# @param port
#   Local Twenty upstream port used by Nginx when `server_name` is set. The default `3000` matches the bundled Compose listener.
#
# @param redis_url
#   Redis connection URL written as `REDIS_URL`.
#
# @param secret_key_fallback
#   Optional previous secret key written as `FALLBACK_ENCRYPTION_KEY` during a key rotation.
#
# @param server_name
#   Optional public Nginx `server_name`.
#   When unset or empty, only `docker::compose` is declared and `SERVER_URL` is derived from `host`.
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
# @param storage_s3_access_key_id
#   Optional S3 access key ID written as `STORAGE_S3_ACCESS_KEY_ID`.
#
# @param storage_s3_endpoint
#   Optional S3 endpoint written as `STORAGE_S3_ENDPOINT`.
#
# @param storage_s3_name
#   Optional S3 bucket name written as `STORAGE_S3_NAME`.
#
# @param storage_s3_region
#   Optional S3 region written as `STORAGE_S3_REGION`.
#
# @param storage_s3_secret_access_key
#   Optional S3 secret access key written as `STORAGE_S3_SECRET_ACCESS_KEY`.
#
# @param storage_type
#   Twenty storage backend written as `STORAGE_TYPE`.
#
# @param target
#   `basic_settings::systemd` target suffix that should bind to the generated Compose service. The default is `services`.
#
# @api public
define docker::twenty (
  Sensitive[String]                     $database_password,
  Sensitive[String]                     $secret_key,
  Pattern[/\A[^\r\n]+\z/]               $database_host                = 'db',
  Integer[1, 65535]                     $database_port                = 5432,
  Pattern[/\A[^\r\n]+\z/]               $database_user                = 'postgres',
  Enum['present', 'absent']             $ensure                       = present,
  Pattern[/\A[^\r\n]+\z/]               $host                         = '127.0.0.1',
  Pattern[/\A[^\r\n]+\z/]               $image_tag                    = 'latest',
  Integer                               $monitoring_detail_limit      = 6000,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_expected_exited   = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_health_required   = [],
  Integer                               $monitoring_interval          = 300,
  Boolean                               $monitoring_orphan_critical   = false,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_profiles          = [],
  Integer                               $monitoring_starting_grace    = 300,
  Integer                               $monitoring_timeout           = 60,
  Integer[1, 65535]                     $port                         = 3000,
  Pattern[/\A[^\r\n]+\z/]               $redis_url                    = 'redis://redis:6379',
  Optional[Sensitive[String]]           $secret_key_fallback          = undef,
  Optional[String]                      $server_name                  = undef,
  Optional[String]                      $ssl_certificate              = undef,
  Optional[String]                      $ssl_certificate_key          = undef,
  Optional[String]                      $ssl_certificate_trusted      = undef,
  Optional[Sensitive[String]]           $storage_s3_access_key_id     = undef,
  Optional[Pattern[/\A[^\r\n]*\z/]]     $storage_s3_endpoint          = undef,
  Optional[Pattern[/\A[^\r\n]*\z/]]     $storage_s3_name              = undef,
  Optional[Pattern[/\A[^\r\n]*\z/]]     $storage_s3_region            = undef,
  Optional[Sensitive[String]]           $storage_s3_secret_access_key = undef,
  Enum['local', 's3']                   $storage_type                 = 'local',
  String                                $target                       = 'services',
) {
  # Validate required parent classes before delegating to the shared Compose wrappers.
  $docker_defined = defined(Class['docker'])
  $nginx_defined = defined(Class['nginx'])

  if ($server_name == undef or ($server_name != undef and $server_name == '')) {
    $server_name_correct = undef
  } else {
    $server_name_correct = $server_name
  }

  if ($docker_defined and ($server_name_correct == undef or $nginx_defined)) {
    # Build Twenty's public URL from the first public vhost name when available, otherwise from the direct host fallback.
    if ($server_name_correct != undef) {
      # Determine the scheme based on the presence of TLS certificate and key.
      if ($ssl_certificate != undef and $ssl_certificate_key != undef) {
        $scheme = 'https'
      } else {
        $scheme = 'http'
      }

      $server_url_host = split($server_name_correct, ' ')[0]
      $server_url_correct = "${scheme}://${server_url_host}"
    } else {
      $server_url_correct = "http://${host}"
    }

    # Generate .env content for the Compose stack based on the provided parameters.
    $env_content = Sensitive.new(template('docker/twenty.env'))

    # Use the proxy wrapper only when a public Nginx vhost is requested.
    if ($server_name_correct != undef) {
      docker::compose_proxy { $name:
        ensure                     => $ensure,
        env_content                => $env_content,
        compose_source             => 'puppet:///modules/docker/twenty.yaml',
        monitoring_detail_limit    => $monitoring_detail_limit,
        monitoring_expected_exited => $monitoring_expected_exited,
        monitoring_health_required => $monitoring_health_required,
        monitoring_interval        => $monitoring_interval,
        monitoring_orphan_critical => $monitoring_orphan_critical,
        monitoring_profiles        => $monitoring_profiles,
        monitoring_starting_grace  => $monitoring_starting_grace,
        monitoring_timeout         => $monitoring_timeout,
        proxy_host                 => $host,
        proxy_port                 => $port,
        proxy_scheme               => 'http', # lint:ignore:140chars The proxy scheme is always `http` because the Compose stack listens on HTTP, even when the public URL is HTTPS.
        server_name                => $server_name_correct,
        ssl_certificate            => $ssl_certificate,
        ssl_certificate_key        => $ssl_certificate_key,
        ssl_certificate_trusted    => $ssl_certificate_trusted,
        target                     => $target,
        require                    => Class['docker'],
      }
    } else {
      docker::compose { $name:
        ensure                     => $ensure,
        compose_source             => 'puppet:///modules/docker/twenty.yaml',
        env_content                => $env_content,
        monitoring_detail_limit    => $monitoring_detail_limit,
        monitoring_expected_exited => $monitoring_expected_exited,
        monitoring_health_required => $monitoring_health_required,
        monitoring_interval        => $monitoring_interval,
        monitoring_orphan_critical => $monitoring_orphan_critical,
        monitoring_profiles        => $monitoring_profiles,
        monitoring_starting_grace  => $monitoring_starting_grace,
        monitoring_timeout         => $monitoring_timeout,
        target                     => $target,
        require                    => Class['docker'],
      }
    }
  } elsif ($docker_defined) {
    fail('docker::twenty requires the nginx class before it can create a reverse proxy vhost.')
  } else {
    fail('docker::twenty requires the docker class before it can create the Compose stack.')
  }
}
