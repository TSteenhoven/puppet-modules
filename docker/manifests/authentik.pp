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
# @example Deploy Authentik with generated `.env` content
#   class { 'docker': }
#
#   # Deploy the identity service with generated environment credentials.
#   docker::authentik { 'authentik':
#     database_password => Sensitive('replace-with-secret'),
#     secret_key        => Sensitive('replace-with-secret'),
#   }
#
# @example Deploy Authentik behind Nginx
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
#   Optional sender address written as `AUTHENTIK_EMAIL__FROM`. `undef` derives `authentik@<server_name>` or
#   `authentik@basic_settings::server_fdqn` when SMTP is active.
#
# @param smtp_host
#   Optional SMTP relay host written as `AUTHENTIK_EMAIL__HOST`. `undef` inherits `basic_settings::smtp_server` when
#   `basic_settings` is declared.
#
# @param smtp_password
#   Optional SMTP password written as `AUTHENTIK_EMAIL__PASSWORD`. Empty values are omitted from the generated `.env`
#   file.
#
# @param smtp_port
#   Optional SMTP relay port written as `AUTHENTIK_EMAIL__PORT`. `undef` uses `25` only when an SMTP host is available.
#
# @param smtp_timeout
#   Optional SMTP timeout in seconds written as `AUTHENTIK_EMAIL__TIMEOUT`. `undef` uses `10` only when an SMTP host is
#   available.
#
# @param smtp_use_ssl
#   Optional implicit TLS/SSL setting written as `AUTHENTIK_EMAIL__USE_SSL`. `undef` uses `false` only when an SMTP host
#   is available.
#
# @param smtp_use_tls
#   Optional STARTTLS setting written as `AUTHENTIK_EMAIL__USE_TLS`. `undef` uses `false` only when an SMTP host is
#   available.
#
# @param smtp_username
#   Optional SMTP username written as `AUTHENTIK_EMAIL__USERNAME`. Empty values are omitted from the generated `.env`
#   file.
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
  Optional[Pattern[/\A[^\r\n]*\z/]]     $smtp_host                  = undef,
  Optional[Sensitive[String]]           $smtp_password              = undef,
  Optional[Integer[1, 65535]]           $smtp_port                  = undef,
  Optional[Integer[1]]                  $smtp_timeout               = undef,
  Optional[Boolean]                     $smtp_use_ssl               = undef,
  Optional[Boolean]                     $smtp_use_tls               = undef,
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
      # Resolve the SMTP relay host with the same explicit-then-basic_settings ordering used by GitLab's SMTP configuration.
      if ($smtp_host == undef or ($smtp_host != undef and $smtp_host == '')) {
        # Read the central SMTP relay only when basic_settings is available.
        if ($basic_settings_defined) {
          # Use a nonempty central SMTP host; otherwise leave SMTP unconfigured.
          if ($basic_settings::smtp_server != '') {
            # Use the central SMTP relay when a non-empty relay is configured.
            $smtp_host_correct = $basic_settings::smtp_server
          } else {
            # Leave SMTP disabled when no central relay is available.
            $smtp_host_correct = undef
          }
        } else {
          # Leave SMTP disabled when no central relay is available.
          $smtp_host_correct = undef
        }
      } else {
        # Use the explicitly supplied SMTP host.
        $smtp_host_correct = $smtp_host
      }

      # Use Authentik's documented SMTP defaults only after SMTP is active through a resolved host.
      if ($smtp_port == undef) {
        # Apply the default SMTP port only when a relay host has been resolved.
        if ($smtp_host_correct != undef) {
          # Default an enabled SMTP connection to port 25.
          $smtp_port_correct = 25
        } else {
          # Omit the SMTP port when no relay is configured.
          $smtp_port_correct = undef
        }
      } else {
        # Preserve the caller's SMTP port.
        $smtp_port_correct = $smtp_port
      }

      # Preserve an explicit SMTP timeout or choose a default for active SMTP.
      if ($smtp_timeout == undef) {
        # Apply the default SMTP timeout only when a relay host has been resolved.
        if ($smtp_host_correct != undef) {
          # Bound the default SMTP connection timeout to ten seconds.
          $smtp_timeout_correct = 10
        } else {
          # Omit the SMTP timeout when no relay is configured.
          $smtp_timeout_correct = undef
        }
      } else {
        # Preserve the caller's SMTP timeout.
        $smtp_timeout_correct = $smtp_timeout
      }

      # Preserve the caller's implicit-TLS setting and leave inactive SMTP unconfigured.
      if ($smtp_use_ssl == undef) {
        # Default implicit TLS to disabled only for an active SMTP connection.
        if ($smtp_host_correct != undef) {
          # Leave implicit SMTP TLS disabled unless explicitly requested.
          $smtp_use_ssl_correct = false
        } else {
          # Omit the implicit TLS setting when no relay is configured.
          $smtp_use_ssl_correct = undef
        }
      } else {
        # Preserve the caller's implicit SMTP TLS setting.
        $smtp_use_ssl_correct = $smtp_use_ssl
      }

      # Preserve the caller's STARTTLS setting and leave inactive SMTP unconfigured.
      if ($smtp_use_tls == undef) {
        # Default STARTTLS to disabled only for an active SMTP connection.
        if ($smtp_host_correct != undef) {
          # Leave SMTP STARTTLS disabled unless explicitly requested.
          $smtp_use_tls_correct = false
        } else {
          # Omit the STARTTLS setting when no relay is configured.
          $smtp_use_tls_correct = undef
        }
      } else {
        # Preserve the caller's SMTP STARTTLS setting.
        $smtp_use_tls_correct = $smtp_use_tls
      }

      # Reject simultaneous implicit TLS and STARTTLS on one SMTP connection.
      if ($smtp_use_ssl_correct == true and $smtp_use_tls_correct == true) {
        # Record the conflicting SMTP TLS modes before generating application configuration.
        $smtp_tls_fail_text = 'docker::authentik cannot enable both smtp_use_ssl and smtp_use_tls for the same SMTP connection.'
      } else {
        # Allow configuration generation when the SMTP TLS modes do not conflict.
        $smtp_tls_fail_text = undef
      }

      # Keep optional SMTP authentication values out of the generated .env file when callers leave them empty.
      if ($smtp_username == undef or ($smtp_username != undef and $smtp_username == '')) {
        # Omit SMTP authentication when no non-empty username is supplied.
        $smtp_username_correct = undef
      } else {
        # Keep the supplied SMTP authentication username.
        $smtp_username_correct = $smtp_username
      }

      # Validate a supplied SMTP password while keeping absent authentication unconfigured.
      if ($smtp_password != undef) {
        # Unwrap the supplied password only to validate its single-line environment value.
        $smtp_password_unwrapped = $smtp_password.unwrap
        if ($smtp_password_unwrapped =~ /\A[^\r\n]*\z/) {
          # Omit an empty password instead of writing empty SMTP credentials.
          if ($smtp_password_unwrapped == '') {
            # Omit an empty SMTP password from the generated environment.
            $smtp_password_correct = undef
          } else {
            # Use the validated single-line password in the sensitive environment content.
            $smtp_password_correct = $smtp_password_unwrapped
          }
          $smtp_password_fail_text = undef
        } else {
          # Reject a multiline SMTP password before generating environment content.
          $smtp_password_correct = undef
          $smtp_password_fail_text = 'docker::authentik smtp_password must not contain newlines.'
        }
      } else {
        # Leave SMTP password content and its validation error unset when no password is supplied.
        $smtp_password_correct = undef
        $smtp_password_fail_text = undef
      }

      # Derive a sender address from the public Authentik name or the central server FQDN when SMTP is active and no explicit sender is set.
      if ($smtp_from == undef or ($smtp_from != undef and $smtp_from == '')) {
        # Derive a sender only when SMTP has an active relay host.
        if ($smtp_host_correct != undef) {
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

      # Report incompatible TLS modes before any password validation error.
      if ($smtp_tls_fail_text == undef) {
        # Pass on password-validation failures after TLS-mode validation succeeds.
        $smtp_validation_fail_text = $smtp_password_fail_text
      } else {
        # Report the TLS-mode conflict before any password-validation error.
        $smtp_validation_fail_text = $smtp_tls_fail_text
      }

      # Render credentials and manage the stack only after SMTP validation succeeds.
      if ($smtp_validation_fail_text == undef) {
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
        fail($smtp_validation_fail_text)
      }
    } else {
      fail('docker::authentik requires the nginx class before it can create a reverse proxy vhost.')
    }
  } else {
    fail('docker::authentik requires the docker class before it can create the Compose stack.')
  }
}
