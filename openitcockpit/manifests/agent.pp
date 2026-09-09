# @summary Installs and configures the OpenITCOCKPIT monitoring agent.
#
# lint:ignore:140chars
# This class manages the OpenITCOCKPIT agent package, service wiring, custom check directories, persistent check state, `customchecks.ini`, and `/etc/openitcockpit-agent/config.ini`. Defaults are conservative: the agent binds to localhost, Prometheus export is disabled, and push-mode TLS verification is enabled.
# lint:endignore
#
# @example Configure push mode
#   class { 'openitcockpit::agent':
#     push_enable => true,
#     push_url    => 'https://monitoring.example.org',
#     push_apikey => Sensitive('token'),
#   }
#
# @param bind_address
#   Address used by the agent webserver. The default is `127.0.0.1`.
#
# @param cpustats_enable
#   Enables CPU statistics collection.
#
# @param diskstats_enable
#   Enables disk statistics collection.
#
# @param dockerstats_enable
#   Enables Docker statistics collection.
#
# @param ensure
#   Installs and configures the agent when `present`; purges the package when `absent`.
#
# @param libvirt_enable
#   Enables libvirt statistics collection.
#
# @param memory_enable
#   Enables memory statistics collection.
#
# @param netstats_enable
#   Enables network statistics collection.
#
# @param ntp_enable
#   Enables NTP statistics collection.
#
# @param processstats_enable
#   Enables process statistics collection.
#
# @param prometheus_enable
#   Enables the Prometheus exporter when `true`. The default is `false`.
#
# @param proxy
#   Optional proxy URL rendered into the agent configuration.
#
# @param push_apikey
#   Sensitive API key used for push mode. Push mode is only enabled when this, `push_url`, and `push_enable` are all set.
#
# @param push_enable
#   Enables push mode when `true` and the required URL/API key are present.
#
# @param push_url
#   OpenITCOCKPIT server URL used for push mode.
#
# @param sensorstats_enable
#   Optional sensor statistics override. `undef` enables sensors on physical hosts and disables them on virtual machines.
#
# @param services_enable
#   Enables service statistics collection.
#
# @param swap_enable
#   Enables swap statistics collection.
#
# @param userstats_enable
#   Enables user statistics collection.
#
# @param verify_server_certificate
#   Verifies the server certificate in push mode when `true`.
#
# @api public
class openitcockpit::agent (
  String                      $bind_address              = '127.0.0.1',
  Boolean                     $cpustats_enable           = true,
  Boolean                     $diskstats_enable          = true,
  Boolean                     $dockerstats_enable        = true,
  Enum['present', 'absent']   $ensure                    = present,
  Boolean                     $libvirt_enable            = true,
  Boolean                     $memory_enable             = true,
  Boolean                     $netstats_enable           = true,
  Boolean                     $ntp_enable                = true,
  Boolean                     $processstats_enable       = true,
  Boolean                     $prometheus_enable         = false,
  Optional[String]            $proxy                     = undef,
  Optional[Sensitive[String]] $push_apikey               = undef,
  Boolean                     $push_enable               = false,
  Optional[String]            $push_url                  = undef,
  Optional[Boolean]           $sensorstats_enable        = undef,
  Boolean                     $services_enable           = true,
  Boolean                     $swap_enable               = true,
  Boolean                     $userstats_enable          = true,
  Boolean                     $verify_server_certificate = true,
) {
  # Set variables
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  $systemd_enable = defined(Package['systemd'])

  # Check if we have systemd
  if ($monitoring_enable) {
    $monitoring_package = $basic_settings::monitoring::package
  } else {
    $monitoring_package = 'none'
  }

  # Check if we have sensorstats
  if ($sensorstats_enable == undef) {
    if ($facts['is_virtual']) {
      $sensorstats_correct = false
    } else {
      $sensorstats_correct = true
    }
  } else {
    $sensorstats_correct = $sensorstats_enable
  }

  # Get push state
  if ($push_enable and $push_url != undef and $push_apikey != undef) {
    $push_correct = true
    $push_url_correct = $push_url
    $push_apikey_correct = $push_apikey
  } else {
    $push_correct = false
    $push_url_correct = ''
    $push_apikey_correct = ''
  }

  # Convert string to boolean
  $cpustats_string = bool2str($cpustats_enable, 'True', 'False')
  $diskstats_string = bool2str($diskstats_enable, 'True', 'False')
  $dockerstats_string = bool2str($dockerstats_enable, 'True', 'False')
  $libvirt_string = bool2str($libvirt_enable, 'True', 'False')
  $memory_string = bool2str($memory_enable, 'True', 'False')
  $netstats_string = bool2str($netstats_enable, 'True', 'False')
  $ntp_string = bool2str($ntp_enable, 'True', 'False')
  $processstats_string = bool2str($processstats_enable, 'True', 'False')
  $sensorstats_stirng = bool2str($sensorstats_correct, 'True', 'False')
  $services_string = bool2str($services_enable, 'True', 'False')
  $swap_string = bool2str($swap_enable, 'True', 'False')
  $userstats_string = bool2str($userstats_enable, 'True', 'False')
  $push_string = bool2str($push_correct, 'True', 'False')
  $prometheus_string = bool2str($prometheus_enable, 'True', 'False')
  $verify_server_certificate_string = bool2str($verify_server_certificate, 'True', 'False')

  # Check if we need to setup the agent
  if ($ensure == present) {
    # Install OpenITCockpit agent
    if (!defined(Package['openitcockpit-agent'])) {
      package { 'openitcockpit-agent':
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }

    # Check if monitoring package is not configured
    if ($monitoring_package == 'none') {
      if ($systemd_enable) {
        # Disable service
        service { 'monitoring_service':
          ensure  => undef,
          name    => 'openitcockpit-agent',
          enable  => false,
          require => Package['openitcockpit-agent'],
        }

        # Reload systemd deamon
        exec { 'openitcockpit_agent_systemd_daemon_reload':
          command     => '/usr/bin/systemctl daemon-reload',
          refreshonly => true,
          require     => Package['systemd'],
        }

        # Create drop in for x target
        if (defined(Class['basic_settings::systemd'])) {
          basic_settings::systemd_drop_in { 'openitcockpit_agent_dependency':
            target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
            unit          => {
              'BindsTo'   => 'openitcockpit-agent.service',
            },
            daemon_reload => 'openitcockpit_agent_systemd_daemon_reload',
            require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
          }
        }

        # Get unit
        if ($monitoring_enable) {
          $unit = {
            'OnFailure' => 'notify-failed@%i.service',
          }
        } else {
          $unit = {}
        }

        # Create symlink
        file { '/usr/lib/systemd/system/openitcockpit-agent.service':
          ensure  => 'link',
          owner   => 'root',
          group   => 'root',
          target  => '/etc/openitcockpit-agent/init/openitcockpit-agent.service',
          force   => true,
          notify  => Exec['openitcockpit_agent_systemd_daemon_reload'],
          require => Package['openitcockpit-agent'],
        }

        # Create drop in for ncpa service
        basic_settings::systemd_drop_in { 'openitcockpit_agent_settings':
          target_unit   => 'openitcockpit-agent.service',
          unit          => $unit,
          service       => {
            'PrivateDevices' => 'true',
            'PrivateTmp'     => 'true',
            'ProtectHome'    => 'true',
            'ProtectSystem'  => 'full',
            'ReadWritePaths' => '/etc/openitcockpit-agent',
            'UMask'          => '0077',
          },
          daemon_reload => 'openitcockpit_agent_systemd_daemon_reload',
          require       => File['/usr/lib/systemd/system/openitcockpit-agent.service'],
        }
      } else {
        # Enable service
        service { 'monitoring_service':
          ensure  => true,
          name    => 'openitcockpit-agent',
          enable  => true,
          require => Package['openitcockpit-agent'],
        }
      }

      # Create root directory
      file { 'monitoring_location':
        ensure => directory,
        path   => '/etc/openitcockpit-agent',
        mode   => '0755', # Important
        owner  => 'root',
        group  => 'root',
      }

      # Create plugin directory
      file { 'monitoring_location_plugins':
        ensure  => directory,
        path    => '/etc/openitcockpit-agent/plugins',
        mode    => '0700',
        owner   => 'root',
        group   => 'root',
        require => File['monitoring_location'],
      }

      # Keep persistent check state root-only inside the agent tree.
      file { 'monitoring_location_state':
        ensure  => directory,
        path    => '/etc/openitcockpit-agent/state',
        mode    => '0700',
        owner   => 'root',
        group   => 'root',
        require => File['monitoring_location'],
      }

      # Create config config
      concat { '/etc/openitcockpit-agent/customchecks.ini':
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service['monitoring_service'],
        require => File['monitoring_location'],
      }

      # Create fragment 
      concat::fragment { 'monitoring_customchecks_default':
        target  => '/etc/openitcockpit-agent/customchecks.ini',
        content => "# Managed by puppet\n[default]\n",
        order   => '01',
      }
    }

    # Create config file
    file { '/etc/openitcockpit-agent/config.ini':
      ensure  => file,
      content => template('openitcockpit/agent/config.ini'),
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      notify  => Service['monitoring_service'],
      require => File['monitoring_location'],
    }

    # Setup security audit rules
    if (defined(Package['auditd'])) {
      basic_settings::security_audit { 'monitoring':
        rules => [
          '-a never,exit -F arch=b32 -S adjtimex -F exe=/usr/bin/openitcockpit-agent -F auid=unset',
          '-a never,exit -F arch=b64 -S adjtimex -F exe=/usr/bin/openitcockpit-agent -F auid=unset',
        ],
        order => 2,
      }
    }
  } else {
    # Remove OpenITCockpit agent
    package { 'openitcockpit-agent':
      ensure => purged,
    }
  }
}
