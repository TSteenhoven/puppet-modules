# Docker-focused examples for Compose stacks, reverse proxies, bundled apps, Nextcloud AIO, and GitLab Runner.
# Replace hostnames, paths, checksums, and secrets with environment data.

node 'container-basic.example.org' {
  class { 'basic_settings':
    docker_enable              => true,
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
  }

  # Install the container runtime after preparing the host package sources.
  class { 'docker':
    edition => 'ce',
    require => Class['basic_settings'],
  }

  # Back up the db service; credentials stay in the existing container environment.
  # Deploy the stack with database backups and health requirements for long-running services.
  docker::compose { 'example':
    backup_database_type       => 'postgresql',
    backup_service             => 'db',
    compose_checksum           => '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    compose_source             => 'https://downloads.example.org/example/docker-compose.yml',
    env_source                 => 'puppet:///modules/profile/example.env',
    monitoring_detail_limit    => 6000,
    monitoring_expected_exited => ['migrate'],
    monitoring_health_required => ['web', 'db'],
    monitoring_interval        => 300,
    monitoring_orphan_critical => true,
    monitoring_profiles        => ['production'],
    monitoring_starting_grace  => 600,
    monitoring_timeout         => 90,
    target                     => 'services',
    require                    => Class['docker'],
  }

  # The application's own read-only status command prevents repeating initialization.
  docker::compose_exec { 'initialize-example':
    command      => ['/usr/local/bin/app', 'initialize'],
    compose_name => 'example',
    service      => 'web',
    unless       => ['/usr/local/bin/app', 'initialized'],
  }
}

node 'container-cleanup.example.org' {
  class { 'docker': }

  # Back up required data, detach the systemd target binding, reload systemd and stop the stack before applying this removal.
  # Stop the backup timer and service; central directory management removes undeclared unit files.
  # This deletes the entire project directory, including backups; copy required data elsewhere first.
  docker::compose { 'old-example':
    ensure  => absent,
    require => Class['docker'],
  }
}

node 'container-proxy.example.org' {
  class { 'basic_settings':
    docker_enable              => true,
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
    nginx_enable               => true,
  }

  # Prepare the runtime before creating proxied application stacks.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Provide the webserver that terminates TLS for container applications.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Expose the stack through Nginx with verified upstream TLS and WebSocket support.
  docker::compose_proxy { 'custom':
    client_max_body_size          => '100m',
    compose_checksum              => '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    compose_source                => 'puppet:///modules/profile/custom/docker-compose.yml',
    content_security_policy       => "default-src 'self'; object-src 'none'; base-uri 'self'",
    env_content                   => Sensitive.new("COMPOSE_PROJECT_NAME=custom\nAPP_SECRET=replace-with-secret\n"),
    http2_enable                  => true,
    http3_enable                  => false,
    http_enable                   => true,
    https_force                   => true,
    monitoring_detail_limit       => 6000,
    monitoring_expected_exited    => ['migrate'],
    monitoring_health_required    => ['web'],
    monitoring_interval           => 300,
    monitoring_orphan_critical    => true,
    monitoring_profiles           => ['production'],
    monitoring_starting_grace     => 600,
    monitoring_timeout            => 90,
    proxy_extra_directives        => [
      'proxy_buffering off;',
    ],
    proxy_host                    => '127.0.0.1',
    proxy_port                    => 9443,
    proxy_read_timeout            => '86400',
    proxy_scheme                  => 'https',
    proxy_ssl_trusted_certificate => '/etc/ssl/certs/internal-ca.pem',
    proxy_ssl_verify              => true,
    proxy_websocket               => true,
    referrer_policy               => 'same-origin',
    server_name                   => 'custom.example.org',
    ssl_certificate               => '/etc/letsencrypt/live/custom.example.org/fullchain.pem',
    ssl_certificate_key           => '/etc/letsencrypt/live/custom.example.org/privkey.pem',
    ssl_certificate_trusted       => '/etc/letsencrypt/live/custom.example.org/chain.pem',
    strict_transport_security     => 'max-age=31536000; includeSubDomains',
    target                        => 'services',
    x_content_type_options        => 'nosniff',
    x_frame_options               => 'DENY',
    require                       => [Class['docker'], Package['nginx']],
  }
}

node 'authentik.example.org' {
  class { 'basic_settings':
    docker_enable => true,
    nginx_enable  => true,
  }

  # Prepare the container runtime used by the identity service.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Provide TLS termination and security contact information for the identity service.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Deploy the identity service with its database, mail and public TLS settings.
  docker::authentik { 'authentik':
    akadmin_remove             => true,
    database_password          => Sensitive('replace-with-postgresql-password'),
    secret_key                 => Sensitive('replace-with-authentik-secret-key'),
    image_tag                  => '2026.2.2',
    monitoring_detail_limit    => 6000,
    monitoring_expected_exited => ['worker'],
    monitoring_health_required => ['server'],
    monitoring_interval        => 300,
    monitoring_orphan_critical => true,
    monitoring_profiles        => [],
    monitoring_starting_grace  => 600,
    monitoring_timeout         => 90,
    port                       => 9443,
    server_name                => 'auth.example.org',
    smtp_from                  => 'authentik@example.org',
    smtp_password              => Sensitive('replace-with-authentik-smtp-password'),
    smtp_port                  => 587,
    smtp_security              => 'tls',
    smtp_server                => 'smtp.example.org',
    smtp_username              => 'authentik@example.org',
    ssl_certificate            => '/etc/letsencrypt/live/auth.example.org/fullchain.pem',
    ssl_certificate_key        => '/etc/letsencrypt/live/auth.example.org/privkey.pem',
    ssl_certificate_trusted    => '/etc/letsencrypt/live/auth.example.org/chain.pem',
    ssl_verify                 => false,
    target                     => 'services',
    require                    => [Class['docker'], Package['nginx']],
  }

  # Create the named administrator after deploying the identity service.
  docker::authentik_admin { 'platform.admin':
    compose_name => 'authentik',
    email        => 'info@example.org',
    password     => Sensitive('replace-with-authentik-admin-password'),
    require      => Docker::Authentik['authentik'],
  }

  # Remove the retired administrator from the same identity service.
  docker::authentik_admin { 'old.admin':
    ensure       => absent,
    compose_name => 'authentik',
    require      => Docker::Authentik['authentik'],
  }
}

node 'twenty.example.org' {
  class { 'basic_settings':
    docker_enable => true,
    nginx_enable  => true,
  }

  # Prepare the container runtime used by the CRM application.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Provide TLS termination and security contact information for the CRM application.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Deploy the CRM stack with external object storage and explicit health requirements.
  docker::twenty { 'twenty':
    database_password            => Sensitive('replace-with-postgresql-password'),
    secret_key                   => Sensitive('replace-with-secret-key'),
    database_host                => 'db',
    database_port                => 5432,
    database_user                => 'postgres',
    host                         => '127.0.0.1',
    monitoring_detail_limit      => 6000,
    monitoring_expected_exited   => ['worker'],
    monitoring_health_required   => ['server', 'worker'],
    monitoring_interval          => 300,
    monitoring_orphan_critical   => true,
    monitoring_profiles          => [],
    monitoring_starting_grace    => 600,
    monitoring_timeout           => 90,
    port                         => 3000,
    redis_url                    => 'redis://redis:6379',
    secret_key_fallback          => Sensitive('replace-with-old-secret-key'),
    server_name                  => 'twenty.example.org',
    ssl_certificate              => '/etc/letsencrypt/live/twenty.example.org/fullchain.pem',
    ssl_certificate_key          => '/etc/letsencrypt/live/twenty.example.org/privkey.pem',
    ssl_certificate_trusted      => '/etc/letsencrypt/live/twenty.example.org/chain.pem',
    storage_s3_access_key_id     => Sensitive('replace-with-s3-access-key-id'),
    storage_s3_endpoint          => 'https://s3.example.org',
    storage_s3_name              => 'twenty',
    storage_s3_region            => 'eu-central-1',
    storage_s3_secret_access_key => Sensitive('replace-with-s3-secret-access-key'),
    storage_type                 => 's3',
    image_tag                    => 'latest',
    target                       => 'services',
    require                      => [Class['docker'], Package['nginx']],
  }
}

# Complete domain validation and initialization in AIO before expecting OCC defaults, SMTP and S3 registration to succeed.
# AIO requires one installation per Docker daemon; the Compose title does not isolate its fixed container names.
node 'nextcloud.example.org' {
  class { 'basic_settings':
    docker_enable => true,
    nginx_enable  => true,
    smtp_server   => 'smtp.example.org',
  }

  # Prepare the runtime and systemd integration used by the AIO mastercontainer.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Terminate application TLS on the host; AIO's Apache upstream speaks HTTP on loopback.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Keep admin access on loopback for an SSH tunnel; configure backups separately in the AIO interface.
  # SMTP uses basic_settings::smtp_server above; no mail settings are needed on this resource.
  docker::nextcloud { 'nextcloud-aio':
    server_name         => 'cloud.example.org',
    ssl_certificate     => '/etc/letsencrypt/live/cloud.example.org/fullchain.pem',
    ssl_certificate_key => '/etc/letsencrypt/live/cloud.example.org/privkey.pem',
    require             => [Class['docker'], Package['nginx']],
  }

  # Register a path-style endpoint, preserving an explicit false option and fractional connection timeout.
  docker::nextcloud_s3 { 'server1':
    compose_name         => 'nextcloud-aio',
    bucket               => 'nextcloud-01',
    hostname             => 's3.example.org',
    key                  => 'replace-with-first-access-key',
    secret               => Sensitive('replace-with-first-secret'),
    connect_timeout      => 4.2,
    port                 => 8443,
    use_path_style       => true,
    verify_bucket_exists => false,
  }

  # Register an Amazon store independently; Nextcloud supplies defaults for all unspecified options.
  docker::nextcloud_s3 { 'server2':
    compose_name => 'nextcloud-aio',
    bucket       => 'nextcloud-02',
    region       => 'eu-central-1',
    key          => Sensitive('replace-with-second-access-key'),
    secret       => Sensitive('replace-with-second-secret'),
  }
}

# Use a dedicated host or VM for trusted builds: the Runner manager's Docker socket grants host-level access.
node 'gitlab-runner.example.org' {
  class { 'basic_settings':
    docker_enable => true,
  }

  # Install Docker after basic_settings prepares its APT source and systemd targets.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Create the runner in GitLab first; this protected lookup must return its authentication token as Sensitive[String].
  # For encrypted Hiera returning a String, set lookup_options with convert_to: Sensitive for this profile key.
  # Configure tags, protected access and untagged-job acceptance in GitLab when creating or editing the runner.
  # For an internal GitLab, change runner_url and set runner_ip to its IPv4/IPv6 address; see the parameter's network requirements.
  docker::gitlab_runner { 'gitlab-runner':
    auto_register      => true,
    image_tag          => 'latest',
    runner_description => 'docker-runner',
    runner_token       => lookup('profile::gitlab_runner::runner_token', Sensitive[String]),
    runner_url         => 'https://gitlab.com/',
    require            => Class['docker'],
  }

  # After successful registration, remove runner_token and its mandatory lookup; Puppet removes only the bootstrap copy.
  # Before relying on the runner, test checkout, a job with an explicit image and artifact upload on an isolated Linux host.
  # Verify actual manager/job/helper mounts, TLS and cache separately, then repeat Puppet, noop, replacement and reboot checks.
  # Pause and drain jobs before maintenance; follow docker::gitlab_runner's recovery and removal guidance before deleting state.
}
