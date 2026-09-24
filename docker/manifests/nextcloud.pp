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
# values. SMTP has separate optional parameters below; use `docker::nextcloud_occ` directly for other settings.
# Until AIO initialization completes, these resources are skipped without writing configuration. Finish setup through
# the admin UI; the first Puppet run with a successful installation check applies any differing settings.
#
# SMTP shares docker::authentik's parameter names, relay fallback and Sensitive password contract. A resolved relay
# manages mail_smtpmode, mail_smtphost, mail_smtpsecure and boolean mail_smtpauth. Port, timeout, sender and credentials
# are only written when supplied. Omitting these optional values does not remove previously stored values, but
# omitting credentials disables authentication. All mail settings use docker::nextcloud_occ with typed JSON guards;
# no config.php content is managed directly. Nextcloud supports implicit SSL or automatic STARTTLS, not enforced
# STARTTLS; tls is rejected. See
# https://docs.nextcloud.com/server/stable/admin_manual/configuration_server/email_configuration.html.
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
#     admin_whitelist_ips => ['192.0.2.10', '2001:db8::/32'],
#     smtp_server         => 'smtp.example.org',
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
# @param admin_whitelist_ips
#   IPv4/IPv6 addresses or CIDR networks allowed through the admin vhost when admin_server_name is set. A nonempty
#   list adds allow rules followed by deny all at server level. Defaults to []; an empty list leaves access
#   unrestricted.
#   Uses the client address seen by Nginx. Does not restrict the application vhost or direct access to admin_port.
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
#   When set, also maps this hostname to host-gateway in the mastercontainer through Compose extra_hosts.
#   Undef omits that mapping and leaves the application proxy to the deployment; a same-host HTTPS proxy is still
#   required.
#
# @param skeleton_directory
#   Global default skeleton directory written through OCC `config:system:set skeletondirectory`. The default is an
#   empty string, matching upstream AIO's own recommendation to disable the sample-content skeleton.
#
# @param smtp_from
#   Optional plain sender address, split into `mail_from_address` and `mail_domain`. Undef or empty leaves both keys
#   unmanaged so Nextcloud supplies its own sender. Display names are not supported.
#
# @param smtp_password
#   Optional Sensitive password written as mail_smtppassword. Undef or empty omits the key. Requires a nonempty
#   smtp_username; newlines are rejected without logging the password. No authentication method
#   is imposed. Commands, guards and output use the protection in docker::nextcloud_occ; credentials remain
#   visible to administrators who can inspect process arguments.
#
# @param smtp_port
#   Optional relay port written as integer `mail_smtpport`. Undef leaves it unmanaged; Nextcloud defaults to 25.
#
# @param smtp_security
#   Transport mode: none writes an empty mail_smtpsecure for automatic STARTTLS when the relay offers it; ssl
#   writes ssl for implicit TLS. Defaults to none. The tls mode is rejected because Nextcloud cannot enforce
#   STARTTLS. Selecting ssl does not change the port; supply the port required by your relay.
#
# @param smtp_server
#   Optional relay written as mail_smtphost. Undef or empty inherits a nonempty
#   basic_settings::smtp_server when that class is declared. A relay selects SMTP mode and manages transport and
#   authentication. Without a relay, mail settings remain unmanaged; additional SMTP options require a relay.
#
# @param smtp_timeout
#   Optional timeout in seconds written as integer `mail_smtptimeout`. Undef leaves it unmanaged;
#   Nextcloud defaults to 10.
#
# @param smtp_username
#   Optional user written as mail_smtpname. Undef or empty omits the key. Authentication requires both a nonempty
#   username and password. With a relay, mail_smtpauth is true for a complete pair and false without credentials.
#   Omitted credential keys are not written or deleted; existing values remain stored but unused.
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
  Array[Stdlib::IP::Address]            $admin_whitelist_ips        = [],
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
              compose_content            => template('docker/nextcloud.yaml'),
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
              compose_content            => template('docker/nextcloud.yaml'),
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
            # A nonempty whitelist restricts every admin proxy location; an empty list preserves unrestricted access.
            $admin_whitelist_ips_correct = $admin_whitelist_ips.map |String $whitelist_ip| { "allow ${whitelist_ip};" }
            $admin_whitelist_directives = $admin_whitelist_ips.empty ? {
              true    => [],
              default => concat($admin_whitelist_ips_correct, ['deny all;']),
            }

            # Apply access rules at server level so the security.txt proxy inherits the same restrictions.
            docker::proxy { "${name}_admin":
              content_security_policy => false,
              directives              => $admin_whitelist_directives,
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

          # An omitted or empty explicit relay inherits the central relay when its owning class is available.
          if ($smtp_server == undef or $smtp_server == '') {
            # Read the relay only from a declared owner with a configured value.
            if (defined(Class['basic_settings']) and $basic_settings::smtp_server != '') {
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

          # A missing sender keeps Nextcloud's own sender selection intact.
          $smtp_from_correct = $smtp_from ? {
            undef   => undef,
            ''      => undef,
            default => $smtp_from,
          }

          # Nextcloud's mailer cannot enforce STARTTLS; do not silently downgrade a requested transport.
          if ($smtp_credentials_fail_text == undef and $smtp_security != 'tls') {
            # Nextcloud stores a plain sender address as separate local-part and domain keys.
            if ($smtp_from_correct == undef or $smtp_from_correct =~ /\A[^@\s]+@[^@\s]+\z/) {
              # Undef sender fields stay out of the OCC resource set.
              $smtp_sender_parts = $smtp_from_correct ? {
                undef   => [undef, undef],
                default => split($smtp_from_correct, '@'),
              }

              # Optional settings are written only when supplied; transport and authentication follow the resolved relay.
              $smtp_options = {
                'mail_smtpport'     => $smtp_port,
                'mail_smtptimeout'  => $smtp_timeout,
                'mail_smtpname'     => $smtp_username_correct,
                'mail_smtppassword' => $smtp_password_correct,
                'mail_from_address' => $smtp_sender_parts[0],
                'mail_domain'       => $smtp_sender_parts[1],
              }.filter |$setting, $value| { $value != undef }

              # A nondefault transport selection cannot activate SMTP without a relay.
              if ($smtp_server_correct != undef or ($smtp_options.empty and $smtp_security == 'none')) {
                # No relay means no SMTP resources, while the existing global OCC defaults remain independent.
                if ($smtp_server_correct != undef) {
                  # None selects automatic STARTTLS; absent credentials explicitly disable previously configured authentication.
                  $smtp_secure_correct = $smtp_security ? {
                    'ssl'   => 'ssl',
                    default => '',
                  }
                  $smtp_settings = $smtp_options + {
                    'mail_smtpmode'   => 'smtp',
                    'mail_smtphost'   => $smtp_server_correct,
                    'mail_smtpsecure' => $smtp_secure_correct,
                    'mail_smtpauth'   => $smtp_username_correct != undef,
                  }

                  # One OCC resource per key preserves unrelated configuration and correct scalar types.
                  $smtp_settings.each |$setting, $value| {
                    # Serialize credentials only inside protected OCC arguments and comparison values.
                    $value_correct = $value ? {
                      Sensitive => $value.unwrap,
                      default   => $value,
                    }
                    $value_json = stdlib::to_json($value_correct)

                    # Typed JSON comparison prevents repeated writes, including for empty strings and false.
                    docker::nextcloud_occ { "${name}_${setting}":
                      command      => ['config:system:set', $setting, '--type=json', Sensitive("--value=${value_json}")],
                      compose_name => $name,
                      unless       => ['config:system:get', $setting, '--output=json'],
                      unless_json  => Sensitive($value_json),
                    }
                  }
                }
              } else {
                fail('docker::nextcloud SMTP options require smtp_server or a nonempty basic_settings::smtp_server.')
              }
            } else {
              fail('docker::nextcloud smtp_from must be a plain local-part@domain address without a display name.')
            }
          } else {
            # Preserve the specific credential diagnostic before checking Nextcloud's transport limitation.
            $smtp_fail_text = $smtp_credentials_fail_text ? {
              undef   => 'docker::nextcloud cannot enforce STARTTLS: smtp_security tls is unsupported; use none or ssl.',
              default => $smtp_credentials_fail_text,
            }
            fail($smtp_fail_text)
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
