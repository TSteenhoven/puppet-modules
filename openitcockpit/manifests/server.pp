# @summary Installs and wires an OpenITCOCKPIT server stack.
#
# This class prepares the OpenITCOCKPIT directory layout, optional installation symlink, Grafana password file, frontend
# and Naemon paths, Nginx snippets, PHP-FPM pool integration, sudo rules, packages, service target bindings, systemd
# hardening drop-ins, and Grafana admin password reset command. It assumes tight local integration with Nginx, PHP-FPM,
# Naemon, Docker-based graphing, and the OpenITCOCKPIT package layout.
#
# @example Install the server with explicit TLS files
#   class { 'openitcockpit::server':
#     grafana_password    => Sensitive('replace-with-secret'),
#     server_fdqn         => 'monitoring.example.org',
#     ssl_certificate     => '/etc/letsencrypt/live/monitoring/fullchain.pem',
#     ssl_certificate_key => '/etc/letsencrypt/live/monitoring/privkey.pem',
#   }
#
# @param grafana_password
#   Sensitive password used to reset the Grafana admin account after OpenITCOCKPIT installation is complete.
#
# @param install_dir
#   Optional replacement target for `/opt/openitc`. When set, the class creates the directory and symlinks
#   `/opt/openitc` to it.
#
# @param server_fdqn
#   External server FQDN used by templates. `undef` inherits `basic_settings::server_fdqn` or the Facter FQDN.
#
# @param smtp_server
#   SMTP server used by frontend mail configuration. `undef` inherits `basic_settings::smtp_server` or falls back to
#   `127.0.0.1`.
#
# @param ssl_certificate
#   Optional TLS certificate path rendered into the Nginx SSL snippet.
#
# @param ssl_certificate_key
#   Optional TLS private key path rendered into the Nginx SSL snippet.
#
# @param webserver_directives
#   Additional Nginx directives rendered into the OpenITCOCKPIT custom config.
#
# @param webserver_gid
#   Optional webserver group override. `undef` inherits `nginx::run_group` when Nginx is declared, otherwise uses
#   `www-data`.
#
# @param webserver_uid
#   Optional webserver user override. `undef` inherits `nginx::run_user` when Nginx is declared, otherwise uses
#   `www-data`.
#
# @api public
class openitcockpit::server (
  Sensitive[String] $grafana_password,
  Optional[String]  $install_dir          = undef,
  Optional[String]  $server_fdqn          = undef,
  Optional[String]  $smtp_server          = undef,
  Optional[String]  $ssl_certificate      = undef,
  Optional[String]  $ssl_certificate_key  = undef,
  Array[String]     $webserver_directives = [],
  Optional[String]  $webserver_gid        = undef,
  Optional[String]  $webserver_uid        = undef,
) {
  # Security headers are fixed defaults; raw custom directives must not duplicate or override them.
  $webserver_security_header_directives = filter($webserver_directives) |$directive| {
    $directive =~ /(?i)^\s*add_header\s+(x-frame-options|x-content-type-options|content-security-policy|referrer-policy|strict-transport-security)(\s|;)/ # lint:ignore:140chars
  }
  if (!empty($webserver_security_header_directives)) {
    # Report directives that conflict with centrally managed security headers.
    $webserver_security_header_fail_text = join([
      'openitcockpit::server webserver_directives must not set managed security headers because /etc/nginx/openitc/custom.conf manages them by default:', # lint:ignore:140chars
      join($webserver_security_header_directives, ', '),
    ], ' ')
  } else {
    # Allow web configuration generation when no security-header overrides conflict.
    $webserver_security_header_fail_text = undef
  }

  # Build the complete configuration only after validating the supplied settings.
  if ($webserver_security_header_fail_text == undef) {
    # Set some values
    $log_dir = '/var/log/openitc'
    $lib_dir = '/var/lib/openitcockpit'
    $nginx_enable = defined(Class['nginx'])
    $basic_settings_enable = defined(Class['basic_settings'])

    # Try to get smtp server
    if ($smtp_server == undef) {
      # Use the central SMTP relay when available, otherwise use the local relay.
      if ($basic_settings_enable) {
        # Inherit the central SMTP relay.
        $smtp_server_correct = $basic_settings::smtp_server
      } else {
        # Fall back to the local SMTP relay without central settings.
        $smtp_server_correct = '127.0.0.1'
      }
    } else {
      # Use the explicitly supplied SMTP relay.
      $smtp_server_correct = $smtp_server
    }

    # Try to get uid and gid
    if ($webserver_uid == undef or $webserver_gid == undef) {
      # Inherit the Nginx service identity when its integration is available.
      if ($nginx_enable) {
        # Reuse the Nginx worker identity for web-facing files.
        $webserver_uid_correct = $nginx::run_user
        $webserver_gid_correct = $nginx::run_group
      } else {
        # Use the distribution's standard webserver identity without Nginx integration.
        $webserver_uid_correct = 'www-data'
        $webserver_gid_correct = 'www-data'
      }
    } else {
      # Preserve the complete webserver identity supplied by the caller.
      $webserver_uid_correct = $webserver_uid
      $webserver_gid_correct = $webserver_gid
    }

    # Set webserver notify
    if ($nginx_enable) {
      # Refresh Nginx when its managed web configuration changes.
      $webserver_notify = Service['nginx']
    } else {
      # Leave webserver notifications unset without Nginx integration.
      $webserver_notify = undef
    }

    # Try to get server fdqn
    if ($server_fdqn == undef) {
      # Use the central server FQDN when available, otherwise use the networking fact.
      if ($basic_settings_enable) {
        # Inherit the public server name from the central settings.
        $server_fdqn_correct = $basic_settings::server_fdqn
      } else {
        # Fall back to the host's reported FQDN without central settings.
        $server_fdqn_correct = $facts['networking']['fqdn']
      }
    } else {
      # Preserve the caller's public server name.
      $server_fdqn_correct = $server_fdqn
    }

    # Create sudo rule for cake
    basic_settings::login_sudo { 'openitc_cake':
      rule => "Cmnd_Alias OPENITC_CAKE_CMD = /opt/openitc/frontend/bin/cake *\nDefaults!OPENITC_CAKE_CMD !mail_always\nDefaults!OPENITC_CAKE_CMD root_sudo\nroot ALL = (ALL) SETENV: OPENITC_CAKE_CMD", # lint:ignore:140chars
    }

    # Create sudo rule for nagios
    basic_settings::login_sudo { 'openitc_nagios':
      rule => "Cmnd_Alias OPENITC_NAGIOS_CMD = /opt/openitc/nagios/bin/nagios -v /opt/openitc/nagios/etc/nagios.cfg\nDefaults!OPENITC_NAGIOS_CMD !mail_always\nDefaults!OPENITC_NAGIOS_CMD root_sudo\nnagios ALL = (root) OPENITC_NAGIOS_CMD", # lint:ignore:140chars
    }

    # Check if installation dir is given
    if ($install_dir != undef) {
      # Create directory
      $install_dir_correct = $install_dir
      file { 'openitcockpit_install_dir':
        ensure => directory,
        path   => $install_dir,
        owner  => 'root',
        group  => 'root',
        mode   => '0755', # Important for internal scripts
      }

      # Create symlink
      file { '/opt/openitc':
        ensure  => 'link',
        owner   => 'root',
        group   => 'root',
        target  => $install_dir,
        force   => true,
        require => File['openitcockpit_install_dir'],
      }
    } else {
      # Create directory
      $install_dir_correct = '/opt/openitc'
      file { $install_dir_correct:
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755', # Important for internal scripts
      }
    }

    # Create package prerequisite directories before the OpenITCOCKPIT package runs
    file { [
        "${install_dir_correct}/etc",
        "${install_dir_correct}/etc/carbon",
        "${install_dir_correct}/etc/grafana",
        "${install_dir_correct}/etc/mod_gearman",
        "${install_dir_correct}/etc/mysql",
        "${install_dir_correct}/etc/nagios",
        "${install_dir_correct}/etc/nsta",
        "${install_dir_correct}/etc/statusengine",
        "${install_dir_correct}/nagios",
        "${install_dir_correct}/receiver",
        $lib_dir,
        "${lib_dir}/nagios",
        "${lib_dir}/nagios/backup",
        "${lib_dir}/nagios/etc",
        "${lib_dir}/receiver",
        "${lib_dir}/receiver/etc",
        "${lib_dir}/var",
        $log_dir,
      ]:
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755', # Important for internal scripts
        require => File['/opt/openitc'],
    }

    # Create admin password file
    file { "${install_dir_correct}/etc/grafana/admin_password":
      ensure  => file,
      content => Sensitive.new('admin'),
      replace => false,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      require => File["${install_dir_correct}/etc/grafana"],
    }

    # Create symlink
    file { "${install_dir_correct}/nagios/backup":
      ensure  => 'link',
      owner   => 'root',
      group   => 'root',
      target  => "${lib_dir}/nagios/backup",
      force   => true,
      require => File[
        "${install_dir_correct}/nagios",
        "${lib_dir}/nagios/backup"
      ],
    }

    # Create symlink
    file { "${install_dir_correct}/nagios/etc":
      ensure  => 'link',
      owner   => 'root',
      group   => 'root',
      target  => "${lib_dir}/nagios/etc",
      force   => true,
      require => File[
        "${install_dir_correct}/nagios",
        "${lib_dir}/nagios/etc"
      ],
    }

    # Create symlink
    file { "${install_dir_correct}/receiver/etc":
      ensure  => 'link',
      owner   => 'root',
      group   => 'root',
      target  => "${lib_dir}/receiver/etc",
      force   => true,
      require => File[
        "${install_dir_correct}/receiver",
        "${lib_dir}/receiver/etc"
      ],
    }

    # Create symlink
    file { "${install_dir_correct}/var":
      ensure  => 'link',
      owner   => 'root',
      group   => 'root',
      target  => "${lib_dir}/var",
      force   => true,
      require => File[
        $install_dir_correct,
        "${lib_dir}/var"
      ],
    }

    # Create symlink
    file { "${install_dir_correct}/logs":
      ensure  => 'link',
      owner   => 'root',
      group   => 'root',
      target  => $log_dir,
      force   => true,
      require => File[
        $install_dir_correct,
        $log_dir
      ],
    }

    # Install package
    package { [
        'openitcockpit',
        'openitcockpit-frontend-angular',
        'openitcockpit-mod-gearman-worker-go-local',
        'openitcockpit-module-design',
        'openitcockpit-module-grafana',
        'openitcockpit-monitoring-plugins',
      ]:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
        require         => File[
          "${install_dir_correct}/etc/grafana/admin_password",
          "${install_dir_correct}/nagios/backup",
          "${install_dir_correct}/nagios/etc",
          "${install_dir_correct}/receiver/etc",
          "${install_dir_correct}/var",
          "${install_dir_correct}/logs"
        ],
    }

    # Create dirs
    file { [
        "${lib_dir}/nagios/etc/config",
        "${lib_dir}/nagios/var",
        "${lib_dir}/nagios/var/archives",
        "${lib_dir}/nagios/var/cache",
        "${lib_dir}/nagios/var/log",
        "${lib_dir}/nagios/var/rw",
        "${lib_dir}/nagios/var/spool",
        "${lib_dir}/nagios/var/spool/checkresults",
        "${lib_dir}/nagios/var/spool/perfdata",
        "${lib_dir}/nagios/var/stats",
      ]:
        ensure  => directory,
        owner   => 'nagios',
        group   => $webserver_gid,
        mode    => '0755', # Important for internal scripts
        require => Package['openitcockpit'],
    }

    # Create symlink
    file { "${install_dir_correct}/nagios/var":
      ensure  => 'link',
      owner   => 'root',
      group   => 'root',
      target  => "${lib_dir}/nagios/var",
      force   => true,
      require => File[
        "${install_dir_correct}/nagios",
        "${lib_dir}/nagios/var"
      ],
    }

    # Create nagios config
    file { [
        "${lib_dir}/nagios/etc/config/servicedependencies",
        "${lib_dir}/nagios/etc/config/hostdependencies",
        "${lib_dir}/nagios/etc/config/serviceescalations",
        "${lib_dir}/nagios/etc/config/servicegroups",
        "${lib_dir}/nagios/etc/config/services",
        "${lib_dir}/nagios/etc/config/servicetemplates",
        "${lib_dir}/nagios/etc/config/hostescalations",
        "${lib_dir}/nagios/etc/config/hostgroups",
        "${lib_dir}/nagios/etc/config/timeperiods",
        "${lib_dir}/nagios/etc/config/contactgroups",
        "${lib_dir}/nagios/etc/config/contacts",
        "${lib_dir}/nagios/etc/config/commands",
        "${lib_dir}/nagios/etc/config/hosts",
        "${lib_dir}/nagios/etc/config/hosttemplates",
        "${lib_dir}/nagios/etc/config/defaults",
      ]:
        ensure  => directory,
        owner   => 'root',
        group   => $webserver_gid_correct,
        mode    => '0755',
        require => File["${lib_dir}/nagios/etc/config"],
    }

    # Create resource config
    file { [
        "${install_dir_correct}/etc/nagios/nagios.cfg",
        "${lib_dir}/nagios/etc/resource.cfg",
      ]:
        ensure  => file,
        replace => false,
        owner   => 'nagios',
        group   => $webserver_gid_correct,
        mode    => '0644',
        require => File[
          "${install_dir_correct}/etc/nagios",
          "${lib_dir}/nagios/etc",
        ],
    }

    # Set proper permissions
    file { [
        "${install_dir_correct}/etc/grafana/grafana.ini",
        "${install_dir_correct}/etc/mod_gearman/mod_gearman_neb.conf",
        "${install_dir_correct}/etc/statusengine/statusengine.toml",
      ]:
        ensure  => file,
        replace => false,
        owner   => 'root',
        group   => $webserver_gid_correct,
        mode    => '0644',
        require => Package['openitcockpit'],
    }

    # Create dirs
    file { [
        "${install_dir_correct}/frontend",
        "${install_dir_correct}/frontend/config",
        "${lib_dir}/frontend",
        "${lib_dir}/frontend/tmp",
        "${lib_dir}/frontend/webroot",
        "${lib_dir}/frontend/webroot/img",
      ]:
        ensure  => directory,
        owner   => $webserver_uid_correct,
        group   => $webserver_gid_correct,
        mode    => '0755', # Important for internal scripts
        require => Package['openitcockpit'],
    }

    # Create symlink
    file { "${install_dir_correct}/frontend/tmp":
      ensure  => 'link',
      owner   => 'root',
      group   => 'root',
      target  => "${lib_dir}/frontend/tmp",
      force   => true,
      require => File["${lib_dir}/frontend/tmp"],
    }

    # Create symlink
    file { "${install_dir_correct}/frontend/webroot/img":
      ensure  => 'link',
      owner   => 'root',
      group   => 'root',
      target  => "${lib_dir}/frontend/webroot/img",
      force   => true,
      require => File["${lib_dir}/frontend/webroot/img"],
    }

    # Set proper permissions
    file { [
        "${install_dir_correct}/frontend/config/dbbackend.php",
        "${install_dir_correct}/frontend/config/graphite.php",
        "${install_dir_correct}/frontend/config/perfdatabackend.php",
      ]:
        ensure  => file,
        replace => false,
        owner   => $webserver_uid_correct,
        group   => $webserver_gid_correct,
        mode    => '0664',
        require => File["${install_dir_correct}/frontend/config"],
    }

    # Create email config file
    file { "${install_dir_correct}/frontend/config/email.php":
      ensure  => file,
      content => template('openitcockpit/frontend/email.php'),
      owner   => $webserver_uid_correct,
      group   => $webserver_gid_correct,
      mode    => '0664',
      require => File["${install_dir_correct}/frontend/config"],
    }

    # Get SSL content
    if ($ssl_certificate != undef and $ssl_certificate_key != undef) {
      # Render the supplied certificate pair into the Nginx TLS fragment.
      $ssl_content = template('openitcockpit/nginx/ssl_cert.conf')
    } else {
      # Omit the TLS fragment without a complete certificate pair.
      $ssl_content = ''
    }

    # Create openitc directory
    file { '/etc/nginx/openitc':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      require => Package['openitcockpit'],
    }

    # Set nginx config
    file { '/etc/nginx/sites-enabled/openitc':
      ensure  => 'link',
      owner   => 'root',
      group   => 'root',
      target  => '/etc/nginx/sites-available/openitc',
      force   => true,
      require => File['/etc/nginx/openitc'],
    }

    # Create SSL config file
    file { '/etc/nginx/openitc/ssl_cert.conf':
      ensure  => file,
      content => $ssl_content,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      require => File['/etc/nginx/openitc'],
      notify  => $webserver_notify,
    }

    # Create custom config file
    file { '/etc/nginx/openitc/custom.conf':
      ensure  => file,
      content => template('openitcockpit/nginx/custom.conf'),
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      require => File['/etc/nginx/openitc'],
      notify  => $webserver_notify,
    }

    # Check if php FPM is enabled
    if (defined(Class['php8::fpm'])) {
      php8::fpm_pool { 'oitc':
        listen => '/run/php/php-fpm-oitc.sock',
      }
    }

    # Share component services between native activation and systemd target integration.
    $component_services = [
      'gearman-job-server',
      'gearman_worker',
      'openitcockpit-node',
      'openitcockpit-graphing',
      'oitc_cmd',
      'oitc_cronjobs.timer',
      'push_notification',
      'statusengine',
      'sudo_server',
    ]

    # Disable service
    if (defined(Package['systemd'])) {
      # Disable service
      service { $component_services:
        ensure  => undef,
        enable  => false,
        require => Package['openitcockpit'],
      }

      # Reload systemd deamon
      exec { 'openitcockpit_systemd_daemon_reload':
        command     => '/usr/bin/systemctl daemon-reload',
        refreshonly => true,
        require     => Package['systemd'],
      }

      # Create drop in for x target
      if (defined(Class['basic_settings::systemd'])) {
        basic_settings::systemd_drop_in { 'openitcockpit_gearman_job_server_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
          unit          => {
            'BindsTo'   => 'gearman-job-server.service',
          },
          daemon_reload => 'openitcockpit_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
        }

        # Tie the services target to the Gearman worker lifecycle.
        basic_settings::systemd_drop_in { 'openitcockpit_gearman_worker_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
          unit          => {
            'BindsTo'   => 'gearman_worker.service',
          },
          daemon_reload => 'openitcockpit_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
        }

        # Tie the production target to the OpenITCOCKPIT node service lifecycle.
        basic_settings::systemd_drop_in { 'openitcockpit_node_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-production.target",
          unit          => {
            'BindsTo'   => 'openitcockpit-node.service',
          },
          daemon_reload => 'openitcockpit_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-production"],
        }

        # Tie the production target to the graphing service lifecycle.
        basic_settings::systemd_drop_in { 'openitcockpit_graphing_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-production.target",
          unit          => {
            'BindsTo'   => 'openitcockpit-graphing.service',
          },
          daemon_reload => 'openitcockpit_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-production"],
        }

        # Tie the services target to the monitoring command processor lifecycle.
        basic_settings::systemd_drop_in { 'openitcockpit_oitc_cmd_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
          unit          => {
            'BindsTo'   => 'oitc_cmd.service',
          },
          daemon_reload => 'openitcockpit_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
        }

        # Tie the helpers target to the monitoring cron timer lifecycle.
        basic_settings::systemd_drop_in { 'openitcockpit_oitc_cronjobs_dependency':
          target_unit   => "${basic_settings::cluster_id}-helpers.target",
          unit          => {
            'BindsTo'   => 'oitc_cronjobs.timer',
          },
          daemon_reload => 'openitcockpit_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::cluster_id}-helpers"],
        }

        # Tie the services target to the push notification service lifecycle.
        basic_settings::systemd_drop_in { 'openitcockpit_push_notification_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
          unit          => {
            'BindsTo'   => 'push_notification.service',
          },
          daemon_reload => 'openitcockpit_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
        }

        # Tie the services target to the status engine lifecycle.
        basic_settings::systemd_drop_in { 'openitcockpit_statusengine_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
          unit          => {
            'BindsTo'   => 'statusengine.service',
          },
          daemon_reload => 'openitcockpit_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
        }

        # Tie the services target to the monitoring sudo server lifecycle.
        basic_settings::systemd_drop_in { 'openitcockpit_sudo_server_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
          unit          => {
            'BindsTo'   => 'sudo_server.service',
          },
          daemon_reload => 'openitcockpit_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
        }
      }

      # Get unit
      if (defined(Class['basic_settings::monitoring'])) {
        # Route unit failures through the configured monitoring notification service.
        $unit = {
          'OnFailure' => 'notify-failed@%i.service',
        }
      } else {
        # Leave unit failure hooks empty when monitoring is unavailable.
        $unit = {}
      }

      # Keep the common service isolation separate from umask policy so workers
      # that publish executable files can use the normal system default.
      $service_base = {
        'PrivateDevices' => 'true',
        'PrivateTmp'     => 'true',
        'ProtectHome'    => 'true',
        'ProtectSystem'  => 'full',
      }

      $service_shared_files = stdlib::merge($service_base, {
          # OpenITCOCKPIT components share runtime files between nagios, workers, and the webserver group.
          'UMask'          => '0027',
      })

      basic_settings::systemd_drop_in { 'openitcockpit_gearman_job_server_settings':
        target_unit   => 'gearman-job-server.service',
        unit          => $unit,
        service       => $service_shared_files,
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Package['openitcockpit'],
      }

      # The Gearman worker writes executable files that must stay world-readable
      # and executable, so it intentionally inherits the default 0022 umask.
      basic_settings::systemd_drop_in { 'openitcockpit_gearman_worker_settings':
        target_unit   => 'gearman_worker.service',
        unit          => $unit,
        service       => $service_base,
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Package['openitcockpit'],
      }

      # Apply shared file permissions and failure notifications to the node service.
      basic_settings::systemd_drop_in { 'openitcockpit_node_settings':
        target_unit   => 'openitcockpit-node.service',
        unit          => $unit,
        service       => $service_shared_files,
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Package['openitcockpit'],
      }

      # Apply shared file permissions and failure notifications to the graphing service.
      basic_settings::systemd_drop_in { 'openitcockpit_graphing_settings':
        target_unit   => 'openitcockpit-graphing.service',
        unit          => $unit,
        service       => $service_shared_files,
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Package['openitcockpit'],
      }

      # Apply shared file permissions and failure notifications to the command processor.
      basic_settings::systemd_drop_in { 'openitcockpit_oitc_cmd_settings':
        target_unit   => 'oitc_cmd.service',
        unit          => $unit,
        service       => $service_shared_files,
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Package['openitcockpit'],
      }

      # Apply the shared policy to the cron service executed by the timer.
      basic_settings::systemd_drop_in { 'openitcockpit_oitc_cronjobs_settings':
        target_unit   => 'oitc_cronjobs.service', # oitc_cronjobs.timer
        unit          => $unit,
        service       => $service_shared_files,
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Package['openitcockpit'],
      }

      # Apply shared file permissions and failure notifications to push notifications.
      basic_settings::systemd_drop_in { 'openitcockpit_push_notification_settings':
        target_unit   => 'push_notification.service',
        unit          => $unit,
        service       => $service_shared_files,
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Package['openitcockpit'],
      }

      # Apply shared file permissions and failure notifications to the status engine.
      basic_settings::systemd_drop_in { 'openitcockpit_statusengine_settings':
        target_unit   => 'statusengine.service',
        unit          => $unit,
        service       => $service_shared_files,
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Package['openitcockpit'],
      }

      # Apply shared file permissions and failure notifications to the monitoring sudo server.
      basic_settings::systemd_drop_in { 'openitcockpit_sudo_server_settings':
        target_unit   => 'sudo_server.service',
        unit          => $unit,
        service       => $service_shared_files,
        daemon_reload => 'openitcockpit_systemd_daemon_reload',
        require       => Package['openitcockpit'],
      }
    } else {
      # Enable service
      service { $component_services:
        ensure  => true,
        enable  => true,
        require => Package['openitcockpit'],
      }
    }

    # Update grafana admin password
    # Escape Grafana paths and password before building the reset commands.
    $grafana_password_shell = stdlib::shell_escape($grafana_password.unwrap)
    $grafana_password_file_shell = stdlib::shell_escape("${install_dir_correct}/etc/grafana/admin_password")
    $grafana_graphing_dir_shell = stdlib::shell_escape("${install_dir_correct}/docker/container/graphing")
    $installation_done_file_shell = stdlib::shell_escape("${install_dir_correct}/etc/.installation_done")
    $grafana_password_update_script = "umask 077 && /usr/bin/printf %s ${grafana_password_shell} > ${grafana_password_file_shell} && cd ${grafana_graphing_dir_shell} && /usr/bin/docker exec -i graphing-grafana-1 grafana-cli --homepath=/usr/share/grafana --config=/etc/openitcockpit/grafana/grafana.ini admin reset-admin-password ${grafana_password_shell}" # lint:ignore:140chars
    $grafana_password_check_script = "/usr/bin/test -f ${installation_done_file_shell} && ( ! [ -f ${grafana_password_file_shell} ] || ! /usr/bin/grep -qxF ${grafana_password_shell} ${grafana_password_file_shell} )" # lint:ignore:140chars

    # Escape the complete reset and guard scripts before passing them to sh -c.
    $grafana_password_update_script_shell = stdlib::shell_escape($grafana_password_update_script)
    $grafana_password_check_script_shell = stdlib::shell_escape($grafana_password_check_script)
    exec { 'openitcockpit_grafana_admin_pw':
      command => Sensitive.new("/bin/sh -c ${grafana_password_update_script_shell}"),
      onlyif  => Sensitive.new("/bin/sh -c ${grafana_password_check_script_shell}"),
      require => Package['coreutils', 'grep', 'openitcockpit'],
    }
  } else {
    fail($webserver_security_header_fail_text)
  }
}
