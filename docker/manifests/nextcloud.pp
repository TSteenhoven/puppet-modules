# @summary Deploys the bundled Nextcloud All-in-One (AIO) Docker Compose stack.
#
# This defined type deploys only the AIO mastercontainer through docker::compose. AIO creates and owns its sibling
# containers through the Docker socket, including Apache and the database. Compose prepares the private host
# directory /opt/docker/<title>/backup; select that host path in AIO to use it for local backups. AIO configures
# its Borg backup container itself, without a backup mount or environment setting in the mastercontainer.
# Declare docker first; basic_settings::systemd is needed to start the stack through the shared Compose service.
# The resource title names the managed Compose project. AIO's fixed container and volume names allow only ONE AIO
# installation per Docker daemon, regardless of that title or the chosen ports. Multiple installations require
# separate VMs or Docker daemons, as documented in
# https://github.com/nextcloud/all-in-one/blob/main/multiple-instances.md.
# This wrapper uses the local rootful Docker daemon. Compose monitoring covers the mastercontainer only.
#
# The application upstream is HTTP on loopback because APACHE_PORT enables AIO's external reverse-proxy mode.
# The admin upstream remains self-signed HTTPS on loopback. Optional server_name and admin_server_name publish these
# endpoints through the shared docker::proxy configuration, with docker::compose_proxy owning the application stack.
# Public endpoints require a certificate and key; the certificate must cover every configured public name.
# Without an admin vhost, use an SSH tunnel to the local admin_port to access the admin interface over HTTPS.
# Configure the application domain in AIO after providing its HTTPS reverse proxy; domain validation stays enabled.
# Without server_name, the deployment must provide that HTTPS proxy separately on the same host.
#
# Present stacks always apply this deployment's global OCC defaults (`default_quota`, `default_language`,
# `default_locale`, `default_phone_region`, `default_app`, `skeleton_directory`) through `docker::nextcloud_occ`, each
# guarded so Puppet only writes on an actual difference. There is no opt-out for applying these six, only for their
# values; declare `docker::nextcloud_occ` resources directly for anything else. Until AIO initialization completes,
# these resources fail without writing configuration; finish setup through the admin UI and rerun Puppet.
#
# @example Deploy Nextcloud AIO behind Nginx with both endpoints published
#   include basic_settings
#
#   # Install the runtime after declaring the shared host integration.
#   class { 'docker': }
#
#   # Provide the webserver used by the public endpoints.
#   class { 'nginx': }
#
#   # The certificate must include both cloud.example.org and cloud-admin.example.org.
#   docker::nextcloud { 'nextcloud':
#     server_name         => 'cloud.example.org',
#     admin_server_name   => 'cloud-admin.example.org',
#     ssl_certificate     => '/etc/letsencrypt/live/cloud.example.org/fullchain.pem',
#     ssl_certificate_key => '/etc/letsencrypt/live/cloud.example.org/privkey.pem',
#   }
#
# @param admin_port
#   Local host port bound to the mastercontainer's HTTPS admin UI on 127.0.0.1. Defaults to 8080 and is written as
#   AIO_ADMIN_PORT. Nginx uses the same upstream port when admin_server_name is set. Must differ from port;
#   ports 80 and 443 are unavailable when either Nginx proxy is enabled. The container's own port remains 8080.
#
# @param admin_server_name
#   Optional public Nginx `server_name` for the AIO admin UI. When set, creates an HTTPS vhost on the standard Nginx
#   listeners with upstream `https://127.0.0.1:<admin_port>`. When unset, access remains local or through an SSH tunnel.
#
# @param default_app
#   Global default app written through OCC `config:system:set defaultapp`.
#
# @param default_language
#   Global default language written through OCC `config:system:set default_language`.
#
# @param default_locale
#   Global default locale written through OCC `config:system:set default_locale`.
#
# @param default_phone_region
#   Global default phone region written through OCC `config:system:set default_phone_region`.
#
# @param default_quota
#   Global default storage quota written through OCC `config:app:set files default_quota`.
#
# @param ensure
#   Defaults to present. Delegates project lifecycle to `docker::compose`. Stop the AIO sibling containers through
#   the admin UI before stopping the mastercontainer and follow the Compose removal contract. Absent removes the
#   project directory, including its local backup directory; preserve backups elsewhere first. AIO volumes remain.
#
# @param image_tag
#   Docker image tag for the mastercontainer, written as `NEXTCLOUD_TAG`. Defaults to `latest`, matching upstream AIO
#   guidance not to pin the mastercontainer image; AIO manages the versions of the containers it spawns separately.
#
# @param monitoring_detail_limit
#   Maximum number of diagnostic characters emitted before the Compose monitoring `Interpretation:` section.
#
# @param monitoring_expected_exited
#   Container names that are allowed to be exited without making the stack critical, such as one-shot migration
#   containers.
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
#   Local HTTP upstream port written as APACHE_PORT and used by Nginx. Defaults to 11000 and binds to 127.0.0.1.
#   Port 443 selects AIO's integrated HTTPS mode and is not supported here. Must differ from admin_port;
#   port 80 is also unavailable when either Nginx proxy is enabled.
#
# @param server_name
#   Optional public hostname for Nextcloud; defaults to undef. Configure this same domain in the AIO interface.
#   Undef leaves the application proxy to the deployment; a same-host HTTPS proxy is still required by AIO.
#
# @param skeleton_directory
#   Global default skeleton directory written through OCC `config:system:set skeletondirectory`. The default is an
#   empty string, matching upstream AIO's own recommendation to disable the sample-content skeleton.
#
# @param ssl_certificate
#   Public TLS certificate path for the generated Nginx vhosts; required when either public name is set.
#   One certificate is shared by both endpoints and must cover both names when both are published.
#
# @param ssl_certificate_key
#   Public TLS private key path; required when either public name is set.
#
# @param ssl_certificate_trusted
#   Optional trusted certificate path for public OCSP configuration.
#
# @param ssl_verify
#   Verifies only the admin upstream certificate. Defaults to false for AIO's self-signed admin certificate, even
#   after domain setup. True requires a matching proxy_ssl_name and proxy_ssl_trusted_certificate configured through
#   nginx http_directives. The application upstream uses HTTP and does not consume this setting.
#
# @param target
#   `basic_settings::systemd` target suffix that should bind to the generated Compose service. The default is
#   `services`.
#
# @api public
define docker::nextcloud (
  Integer[1, 65535]                     $admin_port                 = 8080,
  Optional[String[1]]                   $admin_server_name          = undef,
  String[1]                             $default_app                = 'files',
  String[1]                             $default_language           = 'nl',
  String[1]                             $default_locale             = 'nl_NL',
  String[1]                             $default_phone_region       = 'NL',
  String[1]                             $default_quota              = '10 GB',
  Enum['present', 'absent']             $ensure                     = present,
  Pattern[/\A[^\r\n]+\z/]               $image_tag                  = 'latest',
  Integer                               $monitoring_detail_limit    = 6000,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_expected_exited = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_health_required = [],
  Integer                               $monitoring_interval        = 300,
  Boolean                               $monitoring_orphan_critical = false,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_profiles        = [],
  Integer                               $monitoring_starting_grace  = 300,
  Integer                               $monitoring_timeout         = 60,
  Integer[1, 65535]                     $port                       = 11000,
  Optional[String[1]]                   $server_name                = undef,
  String                                $skeleton_directory         = '',
  Optional[String]                      $ssl_certificate            = undef,
  Optional[String]                      $ssl_certificate_key        = undef,
  Optional[String]                      $ssl_certificate_trusted    = undef,
  Boolean                               $ssl_verify                 = false,
  String                                $target                     = 'services',
) {
  # Nginx is only required when at least one of the two AIO endpoints is published.
  $nginx_required = ($ensure == present and ($server_name != undef or $admin_server_name != undef))

  # Public AIO endpoints need TLS; HTTP upstream and admin ports must be distinct and leave Nginx's listeners free.
  $ports_valid = ($port != 443 and $port != $admin_port
    and (!$nginx_required or !($port in [80, 443] or $admin_port in [80, 443])))
  $tls_valid = (!$nginx_required or ($ssl_certificate != undef and $ssl_certificate != ''
    and $ssl_certificate_key != undef and $ssl_certificate_key != ''))
  if ($ensure == absent or ($ports_valid and $tls_valid)) {
    # Require Docker before creating the Compose stack; a public vhost also needs Nginx.
    if (defined(Class['docker'])) {
      # Require Nginx only when at least one AIO endpoint will get a public vhost.
      if ($nginx_required == false or defined(Class['nginx'])) {
        # Present stacks own deployment and configuration; retirement delegates only removal to Compose.
        if ($ensure == present) {
          # Prepare /opt/docker/<title>/backup through Compose's directory owner; AIO selects the host path in its UI.
          $project_directories = {
            'backup' => {
              'mode' => '0700',
            },
          }

          # Both the Compose listeners and Nginx upstreams receive their ports from this interface.
          $env_content = Sensitive.new(template('docker/nextcloud.env'))

          # Use the proxy wrapper only when the Nextcloud application itself is published.
          if ($server_name != undef) {
            docker::compose_proxy { $name:
              ensure                     => $ensure,
              client_max_body_size       => '0', # lint:ignore:140chars Nextcloud handles large file uploads itself; do not cap the request body at the proxy.
              compose_source             => 'puppet:///modules/docker/nextcloud.yaml',
              content_security_policy    => false, # Nextcloud ships its own CSP; avoid a conflicting proxy-level policy.
              env_content                => $env_content,
              monitoring_detail_limit    => $monitoring_detail_limit,
              monitoring_expected_exited => $monitoring_expected_exited,
              monitoring_health_required => $monitoring_health_required,
              monitoring_interval        => $monitoring_interval,
              monitoring_orphan_critical => $monitoring_orphan_critical,
              monitoring_profiles        => $monitoring_profiles,
              monitoring_starting_grace  => $monitoring_starting_grace,
              monitoring_timeout         => $monitoring_timeout,
              project_directories        => $project_directories,
              proxy_port                 => $port,
              proxy_extra_directives     => [
                'proxy_buffering off;',
                'proxy_request_buffering off;',
                'proxy_socket_keepalive on;',
              ],
              proxy_read_timeout         => '3610s',
              proxy_scheme               => 'http', # AIO disables application TLS when APACHE_PORT selects external proxy mode.
              server_name                => $server_name,
              ssl_certificate            => $ssl_certificate,
              ssl_certificate_key        => $ssl_certificate_key,
              ssl_certificate_trusted    => $ssl_certificate_trusted,
              target                     => $target,
              require                    => Class['docker'],
            }
          } else {
            docker::compose { $name:
              ensure                     => $ensure,
              compose_source             => 'puppet:///modules/docker/nextcloud.yaml',
              env_content                => $env_content,
              monitoring_detail_limit    => $monitoring_detail_limit,
              monitoring_expected_exited => $monitoring_expected_exited,
              monitoring_health_required => $monitoring_health_required,
              monitoring_interval        => $monitoring_interval,
              monitoring_orphan_critical => $monitoring_orphan_critical,
              monitoring_profiles        => $monitoring_profiles,
              monitoring_starting_grace  => $monitoring_starting_grace,
              monitoring_timeout         => $monitoring_timeout,
              project_directories        => $project_directories,
              target                     => $target,
              require                    => Class['docker'],
            }
          }

          # The OCC wrapper orders guarded updates after the stack; installation must finish in AIO first.
          docker::nextcloud_occ { "${name}_default_quota":
            command      => ['config:app:set', 'files', 'default_quota', '--value', $default_quota],
            compose_name => $name,
            unless       => ['config:app:get', 'files', 'default_quota', '--output=json'],
            unless_json  => stdlib::to_json($default_quota),
          }

          # Set the default UI language for new sessions.
          docker::nextcloud_occ { "${name}_default_language":
            command      => ['config:system:set', 'default_language', '--value', $default_language],
            compose_name => $name,
            unless       => ['config:system:get', 'default_language', '--output=json'],
            unless_json  => stdlib::to_json($default_language),
          }

          # Set the default locale for number, date and currency formatting.
          docker::nextcloud_occ { "${name}_default_locale":
            command      => ['config:system:set', 'default_locale', '--value', $default_locale],
            compose_name => $name,
            unless       => ['config:system:get', 'default_locale', '--output=json'],
            unless_json  => stdlib::to_json($default_locale),
          }

          # Set the default region for phone numbers entered without a country prefix.
          docker::nextcloud_occ { "${name}_default_phone_region":
            command      => ['config:system:set', 'default_phone_region', '--value', $default_phone_region],
            compose_name => $name,
            unless       => ['config:system:get', 'default_phone_region', '--output=json'],
            unless_json  => stdlib::to_json($default_phone_region),
          }

          # Set the app users land on after login.
          docker::nextcloud_occ { "${name}_defaultapp":
            command      => ['config:system:set', 'defaultapp', '--value', $default_app],
            compose_name => $name,
            unless       => ['config:system:get', 'defaultapp', '--output=json'],
            unless_json  => stdlib::to_json($default_app),
          }

          # Control the sample content copied into new users' file lists; empty disables it.
          docker::nextcloud_occ { "${name}_skeletondirectory":
            command      => ['config:system:set', 'skeletondirectory', '--value', $skeleton_directory],
            compose_name => $name,
            unless       => ['config:system:get', 'skeletondirectory', '--output=json'],
            unless_json  => stdlib::to_json($skeleton_directory),
          }

          # AIO's separate HTTPS admin endpoint reuses the same proxy implementation without deploying Compose twice.
          if ($admin_server_name != undef) {
            docker::proxy { "${name}_admin":
              content_security_policy => false,
              proxy_port              => $admin_port,
              proxy_scheme            => 'https',
              proxy_ssl_verify        => $ssl_verify,
              server_name             => $admin_server_name,
              ssl_certificate         => $ssl_certificate,
              ssl_certificate_key     => $ssl_certificate_key,
              ssl_certificate_trusted => $ssl_certificate_trusted,
              require                 => Docker::Compose[$name],
            }
          }
        } else {
          docker::compose { $name:
            ensure  => absent,
            require => Class['docker'],
          }
        }
      } else {
        fail('docker::nextcloud requires the nginx class before it can create a reverse proxy vhost.')
      }
    } else {
      fail('docker::nextcloud requires the docker class before it can create the Compose stack.')
    }
  } else {
    fail('docker::nextcloud requires distinct local upstream ports (not 443 or public Nginx ports) and a TLS certificate/key for public endpoints.') # lint:ignore:140chars
  }
}
