# Data service examples for MySQL, RabbitMQ, and vnStat.
# Replace passwords, certificate paths, database names, and interface names with environment data.

node 'database.example.org' {
  class { 'basic_settings':
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
    mysql_enable               => true,
    mysql_version              => 8.0,
  }

  # Configure the database service and encrypted backups after preparing its package source.
  class { 'mysql':
    automysqlbackup_backupdir => '/var/lib/automysqlbackup',
    automysqlbackup_password  => Sensitive('replace-with-backup-password'),
    automysqlbackup_settings  => {
      'encrypt'                       => 'yes',
      'mysql_dump_compression'        => 'bzip2',
      'mysql_dump_single_transaction' => 'yes',
    },
    nice_level                => 12,
    package_name              => 'mysql',
    package_version           => 8.0,
    root_password             => lookup('mysql::root_password'),
    settings                  => {
      'innodb_buffer_pool_size' => '1G',
      'max_connections'         => 500,
    },
    require                   => Class['basic_settings'],
  }

  # Initialize the application schema from an existing SQL import.
  mysql::database { 'app':
    ensure  => present,
    charset => 'utf8mb4',
    collate => 'utf8mb4_unicode_ci',
    import  => '/root/imports/app.sql',
    require => Class['mysql'],
  }

  # Keep the application account local to this database host.
  mysql::user { 'app':
    ensure           => present,
    hostname         => 'localhost',
    password         => lookup('mysql::app_password'),
    password_latency => 'password',
    username         => 'app',
    require          => Class['mysql'],
  }

  # Grant data access without allowing the application to delegate permissions.
  mysql::grant { 'app_rw':
    ensure       => present,
    database     => 'app',
    grant_option => false,
    hostname     => 'localhost',
    privileges   => ['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
    table        => '*',
    username     => 'app',
    require      => [Mysql::Database['app'], Mysql::User['app']],
  }
}

node 'rabbitmq.example.org' {
  class { 'basic_settings':
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
    rabbitmq_enable            => true,
  }

  # Place RabbitMQ in the shared services target after preparing its packages.
  class { 'rabbitmq':
    deprecated_features => ['transient_nonexcl_queues'],
    limit_file          => 20000,
    nice_level          => 12,
    target              => 'services',
    require             => Class['basic_settings'],
  }

  # Require TLS for client connections and disable the plain TCP listener.
  class { 'rabbitmq::tcp':
    ssl_ca_certificate  => '/etc/letsencrypt/live/rabbitmq.example.org/ca_cert.pem',
    ssl_certificate     => '/etc/letsencrypt/live/rabbitmq.example.org/cert.pem',
    ssl_certificate_key => '/etc/letsencrypt/live/rabbitmq.example.org/privkey.pem',
    ssl_port            => 5671,
    ssl_protocols       => ['tlsv1.3', 'tlsv1.2'],
    tcp_enable          => false,
    tcp_port            => 5672,
    require             => Class['rabbitmq'],
  }

  # Prepare the management API and CLI used by the application resources below.
  class { 'rabbitmq::management':
    admin_config_path  => '/etc/rabbitmq/rabbitmqadmin.conf',
    admin_enable       => true,
    admin_password     => lookup('rabbitmq::admin_password'),
    default_queue_type => 'quorum',
    port               => 15672,
    ssl_port           => 15671,
    require            => Class['rabbitmq::tcp'],
  }

  # Keep application messaging resources in a dedicated vhost.
  rabbitmq::management_vhost { 'app':
    ensure  => present,
    type    => 'quorum',
    require => Class['rabbitmq::management'],
  }

  # Route failed messages through a dedicated direct exchange.
  rabbitmq::management_exchange { 'failure_exchange':
    ensure  => present,
    type    => 'direct',
    vhost   => 'app',
    require => Rabbitmq::Management_vhost['app'],
  }

  # Preserve failed messages in a durable quorum queue.
  rabbitmq::management_queue { 'failure_messages':
    ensure  => present,
    durable => true,
    type    => 'quorum',
    vhost   => 'app',
    require => Rabbitmq::Management_exchange['failure_exchange'],
  }

  # Send rejected result messages to the failure exchange and routing key.
  rabbitmq::management_queue { 'result_messages':
    ensure    => present,
    arguments => {
      'x-dead-letter-exchange'    => 'failure_exchange',
      'x-dead-letter-routing-key' => 'failure_messages',
    },
    durable   => true,
    type      => 'quorum',
    vhost     => 'app',
    require   => Rabbitmq::Management_exchange['failure_exchange'],
  }

  # Connect the failure routing key to the queue that retains failed messages.
  rabbitmq::management_binding { 'failure_binding':
    ensure      => present,
    destination => 'failure_messages',
    routing_key => 'failure_messages',
    source      => 'failure_exchange',
    vhost       => 'app',
    require     => [
      Rabbitmq::Management_exchange['failure_exchange'],
      Rabbitmq::Management_queue['failure_messages'],
    ],
  }

  # Create an application account without management roles.
  rabbitmq::management_user { 'app':
    ensure   => present,
    password => lookup('rabbitmq::app_password'),
    tags     => [],
    require  => Class['rabbitmq::management'],
  }

  # Allow message access while keeping topology changes outside the application account.
  rabbitmq::management_user_permissions { 'app_permissions':
    configure => '',
    read      => '.*',
    user      => 'app',
    vhost     => 'app',
    write     => '.*',
    require   => [
      Rabbitmq::Management_user['app'],
      Rabbitmq::Management_vhost['app'],
    ],
  }
}

node 'network-usage.example.org' {
  class { 'vnstat':
    bandwidth_max => 1000,
    nice_level    => 8,
    p95_critical  => 900,
    p95_warning   => 700,
    target        => 'services',
  }

  # Monitor the LAN interface against its own link capacity.
  vnstat::ethernet { 'lan':
    ensure        => present,
    bandwidth_max => 1000,
    interface     => 'ens192',
    order         => '50',
    require       => Class['vnstat'],
  }

  # Give the faster WAN interface independent capacity and traffic thresholds.
  vnstat::ethernet { 'wan':
    ensure        => present,
    bandwidth_max => 10000,
    interface     => 'ens224',
    order         => '60',
    p95_critical  => 8000,
    p95_warning   => 6000,
    require       => Class['vnstat'],
  }
}
