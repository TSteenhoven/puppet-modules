# @summary Deploys the bundled Authentik Docker Compose stack.
#
# This defined type deploys the module-shipped `docker/files/authentik.yaml` Compose file. Declare `docker` before using
# it. The resource title becomes the Compose project name, so multiple Authentik stacks can be managed on the same host
# when ports and public names do not conflict. When `server_name` is set, declare `nginx` as well so
# `docker::compose_proxy` can add the reverse proxy; otherwise the defined type declares `docker::compose` directly. By
# default, the bundled bootstrap `akadmin` user is removed after the stack is managed.
#
# The `custom-templates` directory is created for the stack; supply and maintain its contents separately.
#
# Present stacks always back up the postgresql service and require basic_settings::systemd.
# The generic Compose layer supplies the schedule and retention; this wrapper has no backup opt-out.
#
# @example Deploy Authentik with generated `.env` content
#   include basic_settings
#
#   # Install the runtime after declaring the shared host integration.
#   class { 'docker': }
#
#   # Deploy the identity service with generated environment credentials.
#   docker::authentik { 'authentik':
#     database_password => Sensitive('replace-with-secret'),
#     secret_key        => Sensitive('replace-with-secret'),
#     smtp_server       => 'smtp.example.org',
#   }
#
# @example Deploy Authentik behind Nginx
#   include basic_settings
#
#   # Install the runtime after declaring the shared host integration.
#   class { 'docker': }
#
#   # Provide the webserver used by the public identity endpoint.
#   class { 'nginx': }
#
#   # Expose the identity service through the prepared runtime and webserver.
#   docker::authentik { 'authentik':
#     database_password   => Sensitive('replace-with-secret'),
#     secret_key          => Sensitive('replace-with-secret'),
#     server_name         => 'auth.example.org',
#     ssl_certificate     => '/etc/letsencrypt/live/auth.example.org/fullchain.pem',
#     ssl_certificate_key => '/etc/letsencrypt/live/auth.example.org/privkey.pem',
#   }
#
# @param database_password
#   PostgreSQL password written as `PG_PASS` in the generated `.env` file.
#
# @param secret_key
#   Secret key written as `AUTHENTIK_SECRET_KEY` in the generated `.env` file.
#
# @param akadmin_remove
#   Removes the bundled Authentik bootstrap `akadmin` user through `docker::authentik_admin` when `true`.
#
# @param ensure
#   Defaults to present. Delegates project lifecycle to `docker::compose`; follow its `ensure` contract before removing
#   a stack.
#
# @param image_tag
#   Docker image tag written as `AUTHENTIK_TAG`.
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
#   Local Authentik upstream port used by Nginx when `server_name` is set. The default `9443` matches the bundled
#   Compose HTTPS listener and is also written as `COMPOSE_PORT_HTTPS`.
#
# @param scheme
#   Upstream scheme used by Nginx when `server_name` is set. The default is `https`, so local proxy traffic is
#   encrypted.
#
# @param server_name
#   Optional public Nginx `server_name`. When unset, only `docker::compose` is declared.
#
# @param smtp_from
#   Optional sender address written as `AUTHENTIK_EMAIL__FROM`. `undef` or empty derives `noreply@<first server_name>`
#   or `noreply@basic_settings::server_fdqn` when SMTP is active.
#
# @param smtp_password
#   Optional Sensitive password written as AUTHENTIK_EMAIL__PASSWORD. Undef or empty omits the entry.
#   Requires a nonempty smtp_username; newlines are rejected without logging the password.
#
# @param smtp_port
#   Optional relay port written as AUTHENTIK_EMAIL__PORT. Undef omits it, using Authentik's default of 25.
#
# @param smtp_security
#   Transport mode: none disables both AUTHENTIK_EMAIL__USE_TLS and AUTHENTIK_EMAIL__USE_SSL; tls enables only
#   STARTTLS (USE_TLS); ssl enables only implicit TLS (USE_SSL). Defaults to none. Authentication is independent.
#
# @param smtp_server
#   Optional relay written as AUTHENTIK_EMAIL__HOST. Undef or empty inherits a nonempty
#   basic_settings::smtp_server when that class is declared. Without a relay, SMTP remains unconfigured;
#   supplying additional SMTP options requires a resolved relay.
#
# @param smtp_timeout
#   Optional timeout in seconds written as AUTHENTIK_EMAIL__TIMEOUT. Undef omits it, using Authentik's default of 10.
#
# @param smtp_username
#   Optional user written as AUTHENTIK_EMAIL__USERNAME. Undef or empty omits the entry. Authentication requires
#   both a nonempty username and password; when both are absent, both environment entries are omitted.
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
# @param ssl_verify
#   Verifies the Authentik upstream certificate when proxying over HTTPS. The default is `false` because the bundled
#   stack exposes local HTTPS on `9443` with an application-managed certificate.
#
# @param target
#   `basic_settings::systemd` target suffix that should bind to the generated Compose service. The default is
#   `services`.
#
# @api public
define docker::authentik (
  Sensitive[String]                     $database_password,
  Sensitive[String]                     $secret_key,
  Boolean                               $akadmin_remove             = true,
  Enum['present', 'absent']             $ensure                     = present,
  String                                $image_tag                  = '2026.2.2',
  Integer                               $monitoring_detail_limit    = 6000,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_expected_exited = [],
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_health_required = [],
  Integer                               $monitoring_interval        = 300,
  Boolean                               $monitoring_orphan_critical = false,
  Array[Pattern[/\A[A-Za-z0-9_.-]+\z/]] $monitoring_profiles        = [],
  Integer                               $monitoring_starting_grace  = 300,
  Integer                               $monitoring_timeout         = 60,
  Integer[1, 65535]                     $port                       = 9443,
  Enum['http', 'https']                 $scheme                     = 'https',
  Optional[String]                      $server_name                = undef,
  Optional[Pattern[/\A[^\r\n]*\z/]]     $smtp_from                  = undef,
  Optional[Sensitive[String]]           $smtp_password              = undef,
  Optional[Integer[1, 65535]]           $smtp_port                  = undef,
  Enum['none', 'tls', 'ssl']            $smtp_security              = 'none',
  Optional[Pattern[/\A[^\r\n]*\z/]]     $smtp_server                = undef,
  Optional[Integer[1]]                  $smtp_timeout               = undef,
  Optional[Pattern[/\A[^\r\n]*\z/]]     $smtp_username              = undef,
  Optional[String]                      $ssl_certificate            = undef,
  Optional[String]                      $ssl_certificate_key        = undef,
  Optional[String]                      $ssl_certificate_trusted    = undef,
  Boolean                               $ssl_verify                 = false,
  String                                $target                     = 'services',
) {
  # Share central settings availability between the SMTP fallback paths.
  $basic_settings_defined = defined(Class['basic_settings'])

  # Require Docker and, for a public vhost, Nginx before creating the Authentik stack.
  if (defined(Class['docker'])) {
    # Require Nginx when this stack creates a public vhost.
    if ($server_name == undef or defined(Class['nginx'])) {
      # An omitted or empty explicit relay inherits the central relay when its owning class is available.
      if ($smtp_server == undef or $smtp_server == '') {
        # Read the relay only from a declared owner with a configured value.
        if ($basic_settings_defined and $basic_settings::smtp_server != '') {
          # Reuse the deployment's central relay.
          $smtp_server_correct = $basic_settings::smtp_server
        } else {
          # Leave mail settings unmanaged without a relay.
          $smtp_server_correct = undef
        }
      } else {
        # Explicit application settings take precedence over the central relay.
        $smtp_server_correct = $smtp_server
      }

      # Map the single transport choice to mutually exclusive Authentik flags only for active SMTP.
      if ($smtp_server_correct != undef) {
        # Anonymous internal relays remain the default; explicit tls or ssl selects the corresponding transport.
        $smtp_use_ssl_correct = $smtp_security == 'ssl'
        $smtp_use_tls_correct = $smtp_security == 'tls'
      } else {
        # Leave Authentik's mail defaults intact without a relay.
        $smtp_use_ssl_correct = undef
        $smtp_use_tls_correct = undef
      }

      # Empty credentials are absent; keep a supplied password Sensitive until its protected output is prepared.
      $smtp_username_correct = $smtp_username ? {
        ''      => undef,
        default => $smtp_username,
      }
      $smtp_password_unwrapped = $smtp_password ? {
        undef   => '',
        default => $smtp_password.unwrap,
      }
      $smtp_password_correct = $smtp_password_unwrapped ? {
        ''      => undef,
        default => $smtp_password,
      }

      # Validate credentials without including their values in diagnostic messages.
      if ($smtp_password_unwrapped !~ /\A[^\r\n]*\z/) {
        # Authentik's environment and the shared SMTP interface require a single-line password.
        $smtp_credentials_fail_text = 'SMTP smtp_password must not contain newlines.'
      } elsif (($smtp_username_correct == undef) != ($smtp_password_correct == undef)) {
        # A partial credential pair cannot establish the requested authentication.
        $smtp_credentials_fail_text = 'SMTP authentication requires both smtp_username and a nonempty smtp_password.'
      } else {
        # A complete pair enables authentication; an absent pair leaves the relay anonymous.
        $smtp_credentials_fail_text = undef
      }

      # Derive a sender address from the public Authentik name or the central server FQDN when SMTP is active and no explicit sender is set.
      if ($smtp_from == undef or ($smtp_from != undef and $smtp_from == '')) {
        # Derive a sender only when SMTP has an active relay host.
        if ($smtp_server_correct != undef) {
          # Fall back to the host identity only when no public server name was supplied.
          if ($server_name == undef or $server_name == '') {
            # Read the central server identity only when basic_settings is available.
            if ($basic_settings_defined) {
              # Generate a sender from a nonempty FQDN; otherwise leave it unset.
              if ($basic_settings::server_fdqn != '') {
                # Derive the sender address from the centrally configured FQDN.
                $smtp_from_correct = "noreply@${basic_settings::server_fdqn}"
              } else {
                # Omit the default sender when no central FQDN is available.
                $smtp_from_correct = undef
              }
            } else {
              # Omit the default sender when no central FQDN is available.
              $smtp_from_correct = undef
            }
          } else {
            # Derive the sender address from the first configured server name.
            $smtp_from_server_name = split($server_name, ' ')[0]
            $smtp_from_correct = "noreply@${smtp_from_server_name}"
          }
        } else {
          # Omit the sender address when SMTP is disabled.
          $smtp_from_correct = undef
        }
      } else {
        # Preserve the caller's SMTP sender address.
        $smtp_from_correct = $smtp_from
      }

      # Additional SMTP options require a relay; do not silently configure credentials without a destination.
      $smtp_options = [$smtp_from, $smtp_port, $smtp_timeout,
        $smtp_username_correct, $smtp_password_correct].filter |$value| { $value != undef and $value != '' }
      if ($smtp_credentials_fail_text == undef
        and ($smtp_server_correct != undef or ($smtp_options.empty and $smtp_security == 'none'))) {
        # Generate .env content for the Compose stack based on the provided parameters.
        $env_content = Sensitive.new(template('docker/authentik.env'))

        # Use the proxy wrapper only when a public Nginx vhost is requested.
        if ($server_name != undef) {
          # Determine the appropriate Content Security Policy img-src directive based on the presence of TLS
          if ($ssl_certificate != undef and $ssl_certificate_key != undef) {
            # Limit image sources to HTTPS for the TLS-enabled frontend.
            $content_security_policy_img_src = 'https'
          } else {
            # Allow both HTTP and HTTPS image sources for the plaintext frontend.
            $content_security_policy_img_src = 'http: https'
          }

          # Setup compose proxy
          docker::compose_proxy { $name:
            ensure                     => $ensure,
            backup_database_type       => 'postgresql',
            backup_service             => 'postgresql',
            env_content                => $env_content,
            compose_source             => 'puppet:///modules/docker/authentik.yaml',
            content_security_policy    => "default-src 'self'; img-src ${content_security_policy_img_src}: data:; object-src 'none'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline';", # lint:ignore:140chars
            monitoring_detail_limit    => $monitoring_detail_limit,
            monitoring_expected_exited => $monitoring_expected_exited,
            monitoring_health_required => $monitoring_health_required,
            monitoring_interval        => $monitoring_interval,
            monitoring_orphan_critical => $monitoring_orphan_critical,
            monitoring_profiles        => $monitoring_profiles,
            monitoring_starting_grace  => $monitoring_starting_grace,
            monitoring_timeout         => $monitoring_timeout,
            project_directories        => {
              'custom-templates' => {
                'mode' => '0775',
              },
            },
            proxy_port                 => $port,
            proxy_scheme               => $scheme,
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
            backup_database_type       => 'postgresql',
            backup_service             => 'postgresql',
            compose_source             => 'puppet:///modules/docker/authentik.yaml',
            env_content                => $env_content,
            monitoring_detail_limit    => $monitoring_detail_limit,
            monitoring_expected_exited => $monitoring_expected_exited,
            monitoring_health_required => $monitoring_health_required,
            monitoring_interval        => $monitoring_interval,
            monitoring_orphan_critical => $monitoring_orphan_critical,
            monitoring_profiles        => $monitoring_profiles,
            monitoring_starting_grace  => $monitoring_starting_grace,
            monitoring_timeout         => $monitoring_timeout,
            project_directories        => {
              'custom-templates' => {
                'mode' => '0775',
              },
            },
            target                     => $target,
            require                    => Class['docker'],
          }
        }

        # Remove Authentik's bundled bootstrap admin user through the managed Compose stack contract.
        if ($ensure == present and $akadmin_remove) {
          docker::authentik_admin { "${name}_akadmin":
            ensure       => absent,
            compose_name => $name,
            username     => 'akadmin',
            require      => Docker::Compose[$name],
          }
        }
      } else {
        # Preserve the specific credential diagnostic before checking the relay prerequisite.
        $smtp_fail_text = $smtp_credentials_fail_text ? {
          undef   => 'docker::authentik SMTP options require smtp_server or a nonempty basic_settings::smtp_server.',
          default => $smtp_credentials_fail_text,
        }
        fail($smtp_fail_text)
      }
    } else {
      fail('docker::authentik requires the nginx class before it can create a reverse proxy vhost.')
    }
  } else {
    fail('docker::authentik requires the docker class before it can create the Compose stack.')
  }
}
