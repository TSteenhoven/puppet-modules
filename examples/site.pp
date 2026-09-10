# Example profile-style usage for the first-party modules in this repository.
# Replace hostnames, secrets, package choices, and paths with environment data.

node 'web01.example.org' {
  class { 'basic_settings':
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
    nginx_enable               => true,
    sury_enable                => true,
    systemd_ntp_extra_pools    => ['ntp.example.org'],
  }

  # Prepare the webserver and its security contact information.
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
    require              => Class['basic_settings'],
  }

  # Install the PHP extensions required by the web application.
  class { 'php8':
    curl          => true,
    mbstring      => true,
    mysql         => true,
    xml           => true,
    minor_version => 2,
  }

  # Run the application through PHP-FPM with a bounded memory limit.
  class { 'php8::fpm':
    ini_settings => {
      'memory_limit' => '256M',
    },
    require      => Class['php8'],
  }

  # Serve the application over HTTPS using its deployed certificate.
  nginx::server { 'app.example.org':
    docroot             => '/var/www/app.example.org',
    https_enable        => true,
    https_force         => true,
    server_name         => 'app.example.org',
    ssl_certificate     => '/etc/letsencrypt/live/app.example.org/fullchain.pem',
    ssl_certificate_key => '/etc/letsencrypt/live/app.example.org/privkey.pem',
    require             => [Package['nginx'], Class['php8::fpm']],
  }

  # Restrict SSH access to administration and deployment accounts using keys.
  class { 'ssh':
    allow_users                   => ['admin', 'deploy'],
    password_authentication_users => [],
    permit_root_login             => false,
  }

  # Create the administrator account with credentials supplied by the profile.
  basic_settings::login_user { 'admin':
    gid             => 1001,
    home            => '/home/admin',
    password        => Sensitive('replace-with-password-hash'),
    uid             => 1001,
    authorized_keys => ['ssh-ed25519 AAAA... admin@example.org'],
    require         => Class['basic_settings'],
  }
}

node 'container01.example.org' {
  class { 'basic_settings':
    docker_enable              => true,
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
  }

  # Install the runtime used by the application stack.
  class { 'docker':
    require => Class['basic_settings'],
  }

  # Deploy the stack and require healthy web and database services.
  docker::compose { 'example':
    compose_source             => 'puppet:///modules/profile/example/docker-compose.yml',
    env_content                => Sensitive("COMPOSE_PROJECT_NAME=example\n"),
    monitoring_health_required => ['web', 'db'],
    require                    => Class['docker'],
  }
}

node 'database01.example.org' {
  class { 'basic_settings':
    mysql_enable => true,
  }

  # Configure database administration and backup credentials after preparing packages.
  class { 'mysql':
    automysqlbackup_password => Sensitive('replace-with-backup-password'),
    root_password            => lookup('mysql::root_password'),
    require                  => Class['basic_settings'],
  }

  # Create the schema before granting application access.
  mysql::database { 'app':
    ensure  => present,
    require => Class['mysql'],
  }

  # Provision the application identity from protected Hiera data.
  mysql::user { 'app':
    ensure   => present,
    password => lookup('mysql::app_password'),
    username => 'app',
    require  => Class['mysql'],
  }

  # Grant access only after the application schema and identity exist.
  mysql::grant { 'app':
    ensure   => present,
    database => 'app',
    username => 'app',
    require  => [Mysql::Database['app'], Mysql::User['app']],
  }
}

# Network example for a host that lets Netplan own the primary interface.
node 'network01.example.org' {
  include netplanio

  netplanio::ethernet { 'primary':
    addresses   => ['192.0.2.20/24'],
    interface   => 'ens18',
    nameservers => { 'addresses' => ['192.0.2.53'] },
    routes      => { 'default' => { 'via' => '192.0.2.1' } },
    require     => Class['netplanio'],
  }
}

# GitLab credentials use protected Hiera data because the current public parameter is a String.
node 'gitlab.example.org' {
  class { 'basic_settings':
    gitlab_enable => true,
  }

  # Install GitLab with the protected administrator password and explicit public hostname.
  class { 'gitlab':
    root_password => lookup('gitlab::root_password'),
    server_fdqn   => 'gitlab.example.org',
    require       => Class['basic_settings'],
  }

  # Enable HTTPS in the installed GitLab configuration.
  class { 'gitlab::config':
    https   => true,
    require => Class['gitlab'],
  }
}

# Proxmox changes kernels and schedules a reboot; provide its repository without reusing paths owned by basic_settings.
node 'proxmox01.example.org' {
  include basic_settings

  class { 'proxmox':
    require => Class['basic_settings'],
  }
}
