# Monitoring examples for OpenITCOCKPIT agent mode and custom checks.
# Replace URLs, API keys, and contact addresses with environment data.

node 'monitored-host.example.org' {
  # Add optional deployment expectations to the default firewall checks.
  # Match these input and forwarding base-chains to the rules installed by the consuming deployment.
  class { 'basic_settings':
    firewall_check_args        => [
      '-b', 'inet/filter/input/filter/input/drop',
      '-b', 'inet/filter/forward/filter/forward/drop',
    ],
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
    server_fdqn                => 'monitored-host.example.org',
    systemd_notify_mail        => 'monitoring@example.org',
  }

  include openitcockpit

  class { 'openitcockpit::agent':
    ensure                    => present,
    bind_address              => '127.0.0.1',
    cpustats_enable           => true,
    diskstats_enable          => true,
    dockerstats_enable        => false,
    libvirt_enable            => false,
    memory_enable             => true,
    netstats_enable           => true,
    ntp_enable                => true,
    processstats_enable       => true,
    prometheus_enable         => false,
    proxy                     => undef,
    push_apikey               => Sensitive('replace-with-openitcockpit-api-key'),
    push_enable               => true,
    push_url                  => 'https://monitoring.example.org',
    sensorstats_enable        => undef,
    services_enable           => true,
    swap_enable               => true,
    userstats_enable          => true,
    verify_server_certificate => true,
    require                   => Class['basic_settings'],
  }

  # Register the application health check after the agent is configured.
  basic_settings::monitoring_custom { 'application_health':
    ensure        => present,
    cmd           => '--url https://127.0.0.1/health',
    friendly      => 'Application health',
    interval      => 300,
    root_required => true,
    source        => 'puppet:///modules/profile/check_application_health',
    timeout       => 30,
    require       => Class['openitcockpit::agent'],
  }

  # Add Mirth Connect monitoring to the same agent.
  class { 'openitcockpit::agent_mirth_connect':
    ensure  => present,
    require => Class['openitcockpit::agent'],
  }
}

node 'pull-agent.example.org' {
  class { 'basic_settings':
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
  }

  # Expose the pull agent and exporter deliberately; protect access with host firewall policy.
  class { 'openitcockpit::agent':
    bind_address              => '0.0.0.0',
    prometheus_enable         => true,
    push_enable               => false,
    verify_server_certificate => true,
    require                   => Class['basic_settings'],
  }
}

# Server-side composition expects the OpenITCOCKPIT repository and the local web stack.
node 'monitoring.example.org' {
  class { 'basic_settings':
    monitoring_package   => 'openitcockpit',
    nginx_enable         => true,
    openitcockpit_enable => true,
    sury_enable          => true,
  }

  # Provide the webserver used by the monitoring interface.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Install the PHP runtime needed by the monitoring web application.
  class { 'php8':
    curl          => true,
    minor_version => 3,
    require       => Class['basic_settings'],
  }

  # Connect PHP-FPM to the prepared webserver and PHP runtime.
  class { 'php8::fpm':
    require => [Package['nginx'], Class['php8']],
  }

  include openitcockpit

  class { 'openitcockpit::server':
    grafana_password => Sensitive('replace-with-grafana-admin-password'),
    server_fdqn      => 'monitoring.example.org',
    require          => [Class['basic_settings'], Package['nginx', 'php8.3-fpm']],
  }

  # Add the monitoring engine after the server components are available.
  class { 'naemon':
    require => Class['openitcockpit::server'],
  }

  # Register a monitored host with an explicit address and readable name.
  naemon::host { 'web01':
    address  => '192.0.2.10',
    friendly => 'Webserver 01',
  }
}
