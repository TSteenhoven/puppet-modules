# @summary Installs Naemon integration for OpenITCOCKPIT and manages service wiring.
#
# This class installs the OpenITCOCKPIT Naemon package when the OpenITCOCKPIT package is present, requires the
# OpenITCOCKPIT package resource to be visible before declaration, prepares the Naemon configuration directory, disables
# vendor enablement under systemd, binds the service into the shared target ladder, and applies service hardening that
# still permits the files shared with OpenITCOCKPIT and web-facing tooling.
#
# @example Enable Naemon after OpenITCOCKPIT packages are available
#   include naemon
#
# @api public
class naemon () {
  # Set some values
  $openitcockpit_server_enable = defined(Class['openitcockpit::server'])

  # Service composition consumes the package name and configuration paths prepared by this dependency.
  if (defined(Package['openitcockpit'])) {
    # Use the Naemon package and service account provided by OpenITCockpit.
    $package = 'openitcockpit-naemon'
    $webserver_uid = 'nagios'

    # Inherit the managed OpenITCOCKPIT paths and group when its server class is available.
    if ($openitcockpit_server_enable) {
      # Reuse the managed OpenITCockpit configuration directory and webserver group.
      $config_dir = "${openitcockpit::server::install_dir_correct}/etc/nagios/nagios.cfg.d"
      $webserver_gid = $openitcockpit::server::webserver_gid
    } else {
      # Use the standard OpenITCockpit paths and group without its server class.
      $config_dir = '/opt/openitc/etc/nagios/nagios.cfg.d'
      $webserver_gid = 'www-data'
    }

    # Install package
    package { $package:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['openitcockpit'],
    }

    # lint:ignore:140chars
    # Naemon owns the configuration tree; the web group can traverse and create generated entries while explicit child resources keep their own modes.
    # lint:endignore
    file { $config_dir:
      ensure  => directory,
      owner   => $webserver_uid,
      group   => $webserver_gid,
      mode    => '0660',
      purge   => true,
      force   => true,
      recurse => true,
      require => Package[$package],
    }

    # Disable service
    if (defined(Package['systemd'])) {
      # Disable service
      service { 'naemon':
        ensure  => undef,
        enable  => false,
        require => Package[$package],
      }

      # Reload systemd deamon
      exec { 'naemon_systemd_daemon_reload':
        command     => '/usr/bin/systemctl daemon-reload',
        refreshonly => true,
        require     => Package['systemd'],
      }

      # Create drop in for x target
      if (defined(Class['basic_settings::systemd'])) {
        basic_settings::systemd_drop_in { 'naemon_dependency':
          target_unit   => "${basic_settings::systemd::cluster_id}-helpers.target",
          unit          => {
            'BindsTo'   => 'naemon.service',
          },
          daemon_reload => 'naemon_systemd_daemon_reload',
          require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-helpers"],
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

      # Create drop in for openitcockpit-node service
      basic_settings::systemd_drop_in { 'naemon_settings':
        target_unit   => 'naemon.service',
        unit          => $unit,
        service       => {
          'PrivateDevices' => 'true',
          'PrivateTmp'     => 'true',
          'ProtectHome'    => 'true',
          'ProtectSystem'  => 'full',
          'UMask'          => '0027', # Naemon shares runtime files with OpenITCOCKPIT and web-facing tooling.
        },
        daemon_reload => 'naemon_systemd_daemon_reload',
        require       => Package[$package],
      }

      # Check if we have openitcockpit server
      if ($openitcockpit_server_enable) {
        # Create symlink
        file { '/usr/lib/systemd/system/nagios.service':
          ensure  => 'link',
          owner   => 'root',
          group   => 'root',
          target  => '/usr/lib/systemd/system/naemon.service',
          force   => true,
          notify  => Exec['naemon_systemd_daemon_reload'],
          require => Package[$package],
        }
      }
    } else {
      # Enable service
      service { 'naemon':
        ensure  => true,
        enable  => true,
        require => Package[$package],
      }
    }
  } else {
    fail('The openitcockpit package must be declared before including naemon.')
  }
}
