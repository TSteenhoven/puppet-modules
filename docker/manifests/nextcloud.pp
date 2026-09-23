# @summary Deploys the bundled Nextcloud All-in-One (AIO) Docker Compose stack.
#
# This defined type deploys the module-shipped `docker/files/nextcloud.yaml` Compose file, which contains only the AIO
# mastercontainer. The mastercontainer spawns Nextcloud's own containers, including its Apache reverse proxy, by
# talking to the bound Docker socket; there is no separate database service in this stack for `docker::compose` to
# back up, so AIO's own built-in backup feature is used instead, bound to a project-local `backup` directory.
# Declare `docker` before using it.
#
# AIO exposes two HTTP endpoints once running: the mastercontainer's own admin UI on `admin_port` (used for initial
# domain setup and ongoing backup and update management), and, once Nextcloud is provisioned, its Apache reverse
# proxy on `port`. Both are self-signed HTTPS upstreams until a public domain is configured inside AIO itself.
# Set `server_name` and `admin_server_name` to publish either endpoint through Nginx; `docker::compose_proxy` only
# manages one vhost per Compose stack, so a second, directly declared `nginx::server` covers the admin endpoint.
#
# Present stacks always apply this deployment's global OCC defaults (`default_quota`, `default_language`,
# `default_locale`, `default_phone_region`, `default_app`, `skeleton_directory`) through `docker::nextcloud_occ`, each
# guarded so Puppet only writes on an actual difference. There is no opt-out for applying these six, only for their
# values; declare `docker::nextcloud_occ` resources directly for anything else.
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
#   # Expose the application and the AIO admin UI through the prepared runtime and webserver.
#   docker::nextcloud { 'nextcloud':
#     server_name         => 'cloud.example.org',
#     admin_server_name   => 'cloud-admin.example.org',
#     ssl_certificate     => '/etc/letsencrypt/live/cloud.example.org/fullchain.pem',
#     ssl_certificate_key => '/etc/letsencrypt/live/cloud.example.org/privkey.pem',
#   }
#
# @param admin_port
#   Local host port bound to the mastercontainer's admin UI, written as `AIO_ADMIN_PORT`. Used by Nginx as the
#   upstream port when `admin_server_name` is set.
#
# @param admin_server_name
#   Optional public Nginx `server_name` for the AIO admin UI. When unset, the admin UI is reachable only on
#   `127.0.0.1:<admin_port>` on the host itself.
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
#   Defaults to present. Delegates project lifecycle to `docker::compose`; follow its `ensure` contract before
#   removing a stack.
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
#   Local Nextcloud upstream port used by Nginx when `server_name` is set, written as `APACHE_PORT`. The default
#   `11000` matches AIO's documented default for its spawned Apache reverse proxy.
#
# @param server_name
#   Optional public Nginx `server_name` for the Nextcloud application. When unset, only `docker::compose` is declared
#   and the application stays reachable only on `127.0.0.1:<port>` on the host itself.
#
# @param skeleton_directory
#   Global default skeleton directory written through OCC `config:system:set skeletondirectory`. The default is an
#   empty string, matching upstream AIO's own recommendation to disable the sample-content skeleton.
#
# @param ssl_certificate
#   Public TLS certificate path for the generated Nginx vhost(s).
#
# @param ssl_certificate_key
#   Public TLS private key path for the generated Nginx vhost(s).
#
# @param ssl_certificate_trusted
#   Optional trusted certificate path for public OCSP configuration.
#
# @param ssl_verify
#   Verifies the AIO upstream certificates when proxying over HTTPS. The default is `false` because both AIO
#   endpoints serve self-signed HTTPS until a public domain is configured inside AIO itself.
#
# @param target
#   `basic_settings::systemd` target suffix that should bind to the generated Compose service. The default is
#   `services`.
#
# @api public
define docker::nextcloud (
  Integer[1, 65535]                     $admin_port                 = 8080,
  Optional[String]                      $admin_server_name          = undef,
  String[1]                             $default_app                = 'files',
  String[1]                             $default_language           = 'nl',
  String[1]                             $default_locale             = 'nl_NL',
  String[1]                             $default_phone_region       = 'NL',
  String[1]                             $default_quota              = '10 GB',
  Enum['present', 'absent']             $ensure                     = present,
  String                                $image_tag                  = 'latest',
  Integer                               $monitoring_detail_limit    = 6000,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_expected_exited = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_health_required = [],
  Integer                               $monitoring_interval        = 300,
  Boolean                               $monitoring_orphan_critical = false,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_profiles        = [],
  Integer                               $monitoring_starting_grace  = 300,
  Integer                               $monitoring_timeout         = 60,
  Integer[1, 65535]                     $port                       = 11000,
  Optional[String]                      $server_name                = undef,
  String                                $skeleton_directory         = '',
  Optional[String]                      $ssl_certificate            = undef,
  Optional[String]                      $ssl_certificate_key        = undef,
  Optional[String]                      $ssl_certificate_trusted    = undef,
  Boolean                               $ssl_verify                 = false,
  String                                $target                     = 'services',
) {
  # Nginx is only required when at least one of the two AIO endpoints is published.
  $nginx_required = ($server_name != undef or $admin_server_name != undef)

  # Require Docker before creating the Compose stack; a public vhost also needs Nginx.
  if (defined(Class['docker'])) {
    # Require Nginx only when at least one AIO endpoint will get a public vhost.
    if ($nginx_required == false or defined(Class['nginx'])) {
      # AIO's own backup feature needs a host directory bind-mounted into the mastercontainer.
      $backup_directory = "/opt/docker/${name}/backup"

      # Generate .env content for the Compose stack based on the provided parameters.
      $env_content = Sensitive.new(template('docker/nextcloud.env'))

      # Reserve the backup bind-mount directory alongside the project directory Docker::Compose already manages.
      $project_directories = {
        'backup' => {
          'mode' => '0700',
        },
      }

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
          proxy_scheme               => 'https',
          proxy_ssl_verify           => $ssl_verify,
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

      # Apply the deployment's global OCC defaults and the optional admin vhost only for a stack the operator wants
      # present; both share this condition instead of repeating it on separate top-level blocks.
      if ($ensure == present) {
        # Apply the deployment's global defaults through OCC once the stack is managed; each guard reads the current
        # value back as JSON so Puppet only writes on an actual difference. docker::nextcloud_occ resolves its own
        # ordering against the Docker::Compose[$name]/Docker::Compose_proxy[$name] resource declared above.
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

        # Publish the AIO admin UI separately: docker::compose_proxy manages one vhost per Compose stack, and AIO
        # genuinely needs two upstreams (app and admin), so the second vhost is declared directly here.
        # ponytail: duplicates a handful of docker::compose_proxy's proxy_pass directives instead of a shared helper;
        # promote to a shared directive-builder if a third multi-endpoint app ever needs the same thing.
        if ($admin_server_name != undef) {
          # Resolve the admin vhost's TLS and upstream-verification settings from the shared certificate parameters.
          $admin_ssl_enable = ($ssl_certificate != undef and $ssl_certificate_key != undef)
          $admin_proxy_ssl_verify_value = $ssl_verify ? {
            true    => 'on',
            default => 'off',
          }

          # Publish the admin UI through the vhost settings resolved above.
          nginx::server { "docker_compose_${name}_admin":
            access_log              => "/var/log/nginx/docker_compose_${name}_admin_access.log combined buffer=32k flush=1m", # lint:ignore:140chars
            docroot                 => undef,
            error_log               => "/var/log/nginx/docker_compose_${name}_admin_error.log",
            https_enable            => $admin_ssl_enable,
            https_force             => $admin_ssl_enable,
            location_directives     => [
              "proxy_pass https://127.0.0.1:${admin_port};",
              'proxy_set_header Host $host;',
              'proxy_set_header X-Real-IP $remote_addr;',
              'proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;',
              'proxy_set_header X-Forwarded-Host $host;',
              'proxy_set_header X-Forwarded-Proto $scheme;',
              'proxy_read_timeout 86400;',
              "proxy_ssl_verify ${admin_proxy_ssl_verify_value};",
            ],
            php_fpm_enable          => false,
            server_name             => $admin_server_name,
            ssl_certificate         => $ssl_certificate,
            ssl_certificate_key     => $ssl_certificate_key,
            ssl_certificate_trusted => $ssl_certificate_trusted,
            ssl_ocsp                => $admin_ssl_enable,
            ssl_session_cache       => 'shared:SSL:10m',
            ssl_session_timeout     => '10',
            try_files               => false,
            require                 => Docker::Compose[$name],
          }
        }
      }
    } else {
      fail('docker::nextcloud requires the nginx class before it can create a reverse proxy vhost.')
    }
  } else {
    fail('docker::nextcloud requires the docker class before it can create the Compose stack.')
  }
}
