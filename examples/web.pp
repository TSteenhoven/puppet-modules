# Webserver examples for Nginx, PHP-FPM, and Let's Encrypt.
# Replace hostnames, certificate paths, document roots, and upstreams with environment data.

node 'web-example.example.org' {
  class { 'basic_settings':
    monitoring_package         => 'openitcockpit',
    monitoring_package_install => true,
    nginx_enable               => true,
    server_timezone            => 'Europe/Amsterdam',
    sury_enable                => true,
  }

  # Prepare Certbot before Nginx discovers and installs its certificate plugin.
  class { 'letsencrypt':
    mail_to    => 'security@example.org',
    nice_level => 8,
    require    => Class['basic_settings'],
  }

  # Configure shared TLS, worker limits and security contact defaults for the webserver.
  class { 'nginx':
    events_directives               => ['worker_connections 4096;'],
    global_directives               => ['worker_rlimit_nofile 20000;'],
    http_directives                 => ['server_tokens off;'],
    keepalive_requests              => 1000,
    keepalive_timeout               => '75s',
    limit_file                      => 20000,
    nice_level                      => 10,
    package                         => 'nginx',
    run_group                       => 'www-data',
    run_user                        => 'www-data',
    securitytxt_contacts            => ['mailto:security@example.org'],
    securitytxt_enable              => true,
    securitytxt_encryption          => 'https://example.org/pgp-key.txt',
    securitytxt_expires_days        => 365,
    securitytxt_policy              => 'https://example.org/responsible-disclosure',
    securitytxt_preferred_languages => ['nl', 'en'],
    ssl_prefer_server_ciphers       => true,
    ssl_protocols                   => 'TLSv1.2 TLSv1.3',
    target                          => 'services',
    types_hash_max_size             => 2048,
    variables_hash_bucket_size      => 128,
    variables_hash_max_size         => 2048,
    require                         => Class['basic_settings'],
  }

  # Request one certificate covering both public application names.
  letsencrypt::certificate { 'app.example.org':
    domains => ['app.example.org', 'www.app.example.org'],
    plugin  => 'nginx',
    require => Class['letsencrypt'],
  }

  # Install the PHP runtime and extensions required by this web application.
  class { 'php8':
    apcu               => true,
    bcmath             => true,
    bz2                => true,
    curl               => true,
    gd                 => true,
    gearman            => false,
    gmp                => true,
    imagick            => true,
    imap               => false,
    intl               => true,
    ldap               => false,
    mbstring           => true,
    mcrypt             => false,
    minor_version      => 3,
    msgpack            => true,
    mysql              => true,
    readline           => true,
    redis              => true,
    rrd                => false,
    skip_default_files => false,
    soap               => true,
    sqlite3            => true,
    sybase             => false,
    uploadprogress     => true,
    xdebug             => false,
    xml                => true,
    xmlrpc             => false,
    zip                => true,
    require            => Class['basic_settings'],
  }

  # Give command-line tasks Composer support and their own PHP memory limit.
  class { 'php8::cli':
    composer_enable => true,
    ini_settings    => {
      'memory_limit' => '512M',
    },
    require         => Class['php8'],
  }

  # Configure PHP-FPM logging, upload limits and opcode caching for web requests.
  class { 'php8::fpm':
    errorlog     => '/var/log/php8.3-fpm.log',
    ini_settings => {
      'memory_limit'               => '256M',
      'opcache.enable'             => 1,
      'opcache.memory_consumption' => 256,
      'post_max_size'              => '32M',
      'upload_max_filesize'        => '32M',
    },
    pidfile      => '/run/php/php8.3-fpm.pid',
    require      => [Package['nginx'], Class['php8']],
  }

  # Create the application pool and socket used by its Nginx vhost.
  php8::fpm_pool { 'app':
    group                => 'www-data',
    listen               => '/run/php/php-fpm-app.sock',
    listen_group         => 'www-data',
    listen_mode          => '0660',
    listen_user          => 'www-data',
    pm                   => 'dynamic',
    pm_max_children      => 20,
    pm_max_requests      => 500,
    pm_max_spare_servers => 6,
    pm_min_spare_servers => 2,
    pm_start_servers     => 4,
    user                 => 'www-data',
    require              => Package['php8.3-fpm'],
  }

  # Main and redirect TLS registrations share check_nginx_cert; certificate paths are read from Nginx at runtime.
  # The monitoring helper warns below 30 days and reports critical below 14 days.
  nginx::server { 'app.example.org':
    client_max_body_size      => '32m',
    content_security_policy   => "default-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self'",
    docroot                   => '/var/www/app.example.org/public',
    fastcgi_read_timeout      => 120,
    http2_enable              => true,
    http3_enable              => false,
    http_enable               => true,
    https_enable              => true,
    https_force               => true,
    php_fpm_enable            => true,
    php_fpm_uri               => 'unix:/run/php/php-fpm-app.sock',
    referrer_policy           => 'same-origin',
    securitytxt_contacts      => ['mailto:security@example.org'],
    securitytxt_policy        => 'https://example.org/responsible-disclosure',
    server_name               => 'app.example.org www.app.example.org',
    ssl_certificate           => '/etc/letsencrypt/live/app.example.org/fullchain.pem',
    ssl_certificate_key       => '/etc/letsencrypt/live/app.example.org/privkey.pem',
    ssl_certificate_trusted   => '/etc/letsencrypt/live/app.example.org/chain.pem',
    strict_transport_security => 'max-age=31536000; includeSubDomains',
    try_files                 => '$uri $uri/ /index.php?$query_string',
    x_content_type_options    => 'nosniff',
    x_frame_options           => 'SAMEORIGIN',
    require                   => [Package['nginx'], Class['php8::fpm']],
  }
}

node 'proxy-example.example.org' {
  class { 'nginx':
    securitytxt_contacts => ['mailto:security@example.org'],
  }

  # Proxy HTTPS and WebSocket traffic to the local application backend.
  nginx::server { 'app-proxy.example.org':
    access_log          => '/var/log/nginx/app_proxy_access.log combined buffer=32k flush=1m',
    docroot             => undef,
    error_log           => '/var/log/nginx/app_proxy_error.log',
    http2_enable        => true,
    https_enable        => true,
    https_force         => true,
    location_directives => [
      'proxy_pass https://127.0.0.1:8443;',
      'proxy_ssl_verify off;',
      'proxy_set_header Host $host;',
      'proxy_set_header X-Real-IP $remote_addr;',
      'proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;',
      'proxy_set_header X-Forwarded-Proto $scheme;',
    ],
    locations           => [
      {
        path                => '/wss/',
        location_directives => [
          'proxy_pass https://127.0.0.1:8443;',
          'proxy_http_version 1.1;',
          'proxy_set_header Upgrade $http_upgrade;',
          'proxy_set_header Connection "Upgrade";',
          'proxy_read_timeout 86400;',
        ],
      },
    ],
    php_fpm_enable      => false,
    server_name         => 'app-proxy.example.org',
    ssl_certificate     => '/etc/letsencrypt/live/app-proxy.example.org/fullchain.pem',
    ssl_certificate_key => '/etc/letsencrypt/live/app-proxy.example.org/privkey.pem',
    try_files           => false,
  }
}
