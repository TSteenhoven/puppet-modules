# @summary Deploys the bundled Authentik Docker Compose stack.
#
# lint:ignore:140chars
# This defined type deploys the module-shipped `docker/files/authentik.yaml` Compose file. Declare `docker` before using it. The resource title becomes the Compose project name, so multiple Authentik stacks can be managed on the same host when ports and public names do not conflict. When `server_name` is set, declare `nginx` as well so `docker::compose_proxy` can add the reverse proxy; otherwise the defined type declares `docker::compose` directly. By default, the bundled bootstrap `akadmin` user is removed after the stack is managed.
# lint:endignore
#
# @example Deploy Authentik with generated `.env` content
#   class { 'docker': }
#
#   docker::authentik { 'authentik':
#     database_password => Sensitive('replace-with-secret'),
#     secret_key        => Sensitive('replace-with-secret'),
#   }
#
# @example Deploy Authentik behind Nginx
#   class { 'docker': }
#   class { 'nginx': }
#
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
#   Controls whether the Authentik Compose project directory and service are present or absent.
#
# @param image_tag
#   Docker image tag written as `AUTHENTIK_TAG`.
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
# lint:ignore:140chars
#   Local Authentik upstream port used by Nginx when `server_name` is set. The default `9443` matches the bundled Compose HTTPS listener and is also written as `COMPOSE_PORT_HTTPS`.
# lint:endignore
#
# @param scheme
#   Upstream scheme used by Nginx when `server_name` is set. The default is `https`, so local proxy traffic is encrypted.
#
# @param server_name
#   Optional public Nginx `server_name`. When unset, only `docker::compose` is declared.
#
# @param smtp_from
# lint:ignore:140chars
#   Optional sender address written as `AUTHENTIK_EMAIL__FROM`. `undef` derives `authentik@<server_name>` or `authentik@basic_settings::server_fdqn` when SMTP is active.
# lint:endignore
#
# @param smtp_host
# lint:ignore:140chars
#   Optional SMTP relay host written as `AUTHENTIK_EMAIL__HOST`. `undef` inherits `basic_settings::smtp_server` when `basic_settings` is declared.
# lint:endignore
#
# @param smtp_password
#   Optional SMTP password written as `AUTHENTIK_EMAIL__PASSWORD`. Empty values are omitted from the generated `.env` file.
#
# @param smtp_port
#   Optional SMTP relay port written as `AUTHENTIK_EMAIL__PORT`. `undef` uses `25` only when an SMTP host is available.
#
# @param smtp_timeout
#   Optional SMTP timeout in seconds written as `AUTHENTIK_EMAIL__TIMEOUT`. `undef` uses `10` only when an SMTP host is available.
#
# @param smtp_use_ssl
#   Optional implicit TLS/SSL setting written as `AUTHENTIK_EMAIL__USE_SSL`. `undef` uses `false` only when an SMTP host is available.
#
# @param smtp_use_tls
#   Optional STARTTLS setting written as `AUTHENTIK_EMAIL__USE_TLS`. `undef` uses `false` only when an SMTP host is available.
#
# @param smtp_username
#   Optional SMTP username written as `AUTHENTIK_EMAIL__USERNAME`. Empty values are omitted from the generated `.env` file.
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
# lint:ignore:140chars
#   Verifies the Authentik upstream certificate when proxying over HTTPS. The default is `false` because the bundled stack exposes local HTTPS on `9443` with an application-managed certificate.
# lint:endignore
#
# @param target
#   `basic_settings::systemd` target suffix that should bind to the generated Compose service. The default is `services`.
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
  # Validate required parent classes before delegating to the shared Compose wrappers.
  $docker_defined = defined(Class['docker'])
  $nginx_defined = defined(Class['nginx'])
  $basic_settings_defined = defined(Class['basic_settings'])

  if ($docker_defined and ($server_name == undef or $nginx_defined)) {
    # Resolve the SMTP relay host with the same explicit-then-basic_settings ordering used by GitLab's SMTP configuration.
    if ($smtp_host == undef or ($smtp_host != undef and $smtp_host == '')) {
      if ($basic_settings_defined) {
        if ($basic_settings::smtp_server != '') {
          $smtp_host_correct = $basic_settings::smtp_server
        } else {
          $smtp_host_correct = undef
        }
      } else {
        $smtp_host_correct = undef
      }
    } else {
      $smtp_host_correct = $smtp_host
    }

    # Use Authentik's documented SMTP defaults only after SMTP is active through a resolved host.
    if ($smtp_port == undef) {
      if ($smtp_host_correct != undef) {
        $smtp_port_correct = 25
      } else {
        $smtp_port_correct = undef
      }
    } else {
      $smtp_port_correct = $smtp_port
    }

    if ($smtp_timeout == undef) {
      if ($smtp_host_correct != undef) {
        $smtp_timeout_correct = 10
      } else {
        $smtp_timeout_correct = undef
      }
    } else {
      $smtp_timeout_correct = $smtp_timeout
    }

    if ($smtp_use_ssl == undef) {
      if ($smtp_host_correct != undef) {
        $smtp_use_ssl_correct = false
      } else {
        $smtp_use_ssl_correct = undef
      }
    } else {
      $smtp_use_ssl_correct = $smtp_use_ssl
    }

    if ($smtp_use_tls == undef) {
      if ($smtp_host_correct != undef) {
        $smtp_use_tls_correct = false
      } else {
        $smtp_use_tls_correct = undef
      }
    } else {
      $smtp_use_tls_correct = $smtp_use_tls
    }

    if ($smtp_use_ssl_correct == true and $smtp_use_tls_correct == true) {
      $smtp_tls_fail_text = 'docker::authentik cannot enable both smtp_use_ssl and smtp_use_tls for the same SMTP connection.'
    } else {
      $smtp_tls_fail_text = undef
    }

    # Keep optional SMTP authentication values out of the generated .env file when callers leave them empty.
    if ($smtp_username == undef or ($smtp_username != undef and $smtp_username == '')) {
      $smtp_username_correct = undef
    } else {
      $smtp_username_correct = $smtp_username
    }

    if ($smtp_password == undef) {
      $smtp_password_correct = undef
      $smtp_password_fail_text = undef
    } else {
      $smtp_password_unwrapped = $smtp_password.unwrap
      if ($smtp_password_unwrapped =~ /\A[^\r\n]*\z/) {
        if ($smtp_password_unwrapped == '') {
          $smtp_password_correct = undef
        } else {
          $smtp_password_correct = $smtp_password_unwrapped
        }
        $smtp_password_fail_text = undef
      } else {
        $smtp_password_correct = undef
        $smtp_password_fail_text = 'docker::authentik smtp_password must not contain newlines.'
      }
    }

    # Derive a sender address from the public Authentik name or the central server FQDN when SMTP is active and no explicit sender is set.
    if ($smtp_from == undef or ($smtp_from != undef and $smtp_from == '')) {
      if ($smtp_host_correct != undef) {
        if ($server_name != undef and $server_name != '') {
          $smtp_from_server_name = split($server_name, ' ')[0]
          $smtp_from_correct = "noreply@${smtp_from_server_name}"
        } elsif ($basic_settings_defined) {
          if ($basic_settings::server_fdqn != '') {
            $smtp_from_correct = "noreply@${basic_settings::server_fdqn}"
          } else {
            $smtp_from_correct = undef
          }
        } else {
          $smtp_from_correct = undef
        }
      } else {
        $smtp_from_correct = undef
      }
    } else {
      $smtp_from_correct = $smtp_from
    }

    if ($smtp_tls_fail_text == undef) {
      $smtp_validation_fail_text = $smtp_password_fail_text
    } else {
      $smtp_validation_fail_text = $smtp_tls_fail_text
    }

    if ($smtp_validation_fail_text == undef) {
      # Generate .env content for the Compose stack based on the provided parameters.
      $env_content = Sensitive.new(template('docker/authentik.env'))

      # Use the proxy wrapper only when a public Nginx vhost is requested.
      if ($server_name != undef) {
        # Determine the appropriate Content Security Policy img-src directive based on the presence of TLS
        if ($ssl_certificate != undef and $ssl_certificate_key != undef) {
          $content_security_policy_img_src = 'https'
        } else {
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

      if ($ensure == present and $akadmin_remove) {
        # Remove Authentik's bundled bootstrap admin user through the managed Compose stack contract.
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
  } elsif ($docker_defined) {
    fail('docker::authentik requires the nginx class before it can create a reverse proxy vhost.')
  } else {
    fail('docker::authentik requires the docker class before it can create the Compose stack.')
  }
}
