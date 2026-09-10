# @summary Manages Puppet agent/server package behavior, systemd integration, cleanup timers, and audit rules.
#
# lint:ignore:140chars
# This class disables vendor service enablement, configures Puppet agent and optional Puppet Server/OpenVox Server paths for distro or remote packages, installs cleanup services and timers for filebucket and server reports, adds monitoring where available, and audits Puppet SSL and code directories. Server mode changes service ordering and creates Puppet-owned directories.
# lint:endignore
#
# @example Manage only the Puppet agent integration
#   include basic_settings::puppet
#
# @example Enable a Puppet Server with a smaller JVM heap
#   class { 'basic_settings::puppet':
#     jvm_memory    => '1gb',
#     server_enable => true,
#   }
#
# @param jvm_memory
#   JVM heap size rendered for Puppet Server/OpenVox Server. Valid values are `512mb`, `1gb`, and `2gb`.
#
# @param repo
#   Package layout to use. `distro` uses distribution paths and `remote` uses Puppet Labs/OpenVox-style `/opt/puppetlabs` paths.
#
# @param server_dirname
#   Directory name used for server configuration and state paths. The default is `puppetserver`.
#
# @param server_enable
#   Installs and configures the selected Puppet server package when `true`.
#   `false` manages only agent-side behavior.
#
# @param server_package
#   Puppet server package to install when server mode is enabled. The value also controls the service name mapping.
#
# @api public
class basic_settings::puppet (
  Enum['512mb', '1gb', '2gb'] $jvm_memory     = '2gb',
  Enum['distro', 'remote']    $repo           = 'distro',
  String                      $server_dirname = 'puppetserver',
  Boolean                     $server_enable  = false,
  Enum[
    'openvox-server',
    'puppet-master',
    'puppetserver'
  ]                           $server_package = 'puppetserver',
) {
  # Set some values
  $basic_settings_enable = defined(Class['basic_settings'])
  $systemd_enable = defined(Package['systemd'])

  # Set monitoring variables
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  if ($monitoring_enable) {
    # Inherit the monitoring backend and attach its unit-failure notification hook.
    $monitoring_package = $basic_settings::monitoring::package
    $unit_failure = {
      'OnFailure' => 'notify-failed@%i.service',
    }
  } else {
    # Disable monitoring registration and failure hooks without a monitoring class.
    $monitoring_package = 'none'
    $unit_failure = {}
  }

  # Get puppet service name
  case $server_package {
    'openvox-server': {
      # Map the OpenVox server package to its puppetserver service name.
      $server_service = 'puppetserver'
    }
    default: {
      # Use the server package name as the service name for the remaining package paths.
      $server_service = $server_package
    }
  }

  # Do some things based on server repo
  case $repo {
    'remote': {
      # Resolve the packaged agent's executable and configuration directories.
      $package_etc_dir = '/etc/puppetlabs'
      $agent_bin_dir = '/opt/puppetlabs/bin'
      $agent_etc_dir = "${package_etc_dir}/puppet"

      # Resolve bundled Ruby and the server's configuration, log and runtime directories.
      $ruby_bin = '/opt/puppetlabs/puppet/bin/ruby'
      $server_dir = '/opt/puppetlabs/server'
      $server_etc_dir = "${package_etc_dir}/${server_dirname}"
      $server_report_dir = "/var/log/puppetlabs/${server_dirname}/reports"
      $server_var_dir = "${server_dir}/data/${server_dirname}"

      # Set auxiliary server data and agent cache paths.
      $server_var_extra = "/var/lib/puppetlabs/${server_dirname}"
      $cache_dir = '/opt/puppetlabs/puppet/cache'

      # Set list
      $require_dirs = [
        $server_report_dir,
        '/var/lib/puppetlabs',
        $server_var_extra,
        "${server_var_extra}/temp",
      ]

      # Install some puppet packages
      package { ['augeas-tools', 'facter']:
        ensure => purged,
      }
    }
    default: {
      # Resolve the distribution agent's executable and configuration directories.
      $package_etc_dir = '/etc'
      $agent_bin_dir = '/usr/bin'
      $agent_etc_dir = "${package_etc_dir}/puppet"

      # Resolve system Ruby and the distribution server directories.
      $ruby_bin = '/usr/bin/ruby'
      $server_dir = "/var/lib/${server_dirname}"
      $server_etc_dir = "${package_etc_dir}/${server_dirname}"
      $server_report_dir = "/var/log/${server_dirname}/reports"
      $server_var_dir = $server_dir
      $server_var_extra = $server_var_dir

      # Get clean filebucket dir
      if ($server_enable) {
        # Keep server caches under the selected server implementation's directory.
        $cache_dir = "/var/cache/${server_dirname}"
      } else {
        # Use the agent cache directory when no server is enabled.
        $cache_dir = '/var/cache/puppet'
      }

      # Set list
      $require_dirs = [
        $server_report_dir,
        $server_var_extra,
        "${server_var_extra}/temp",
      ]

      # Install some puppet packages
      package { ['augeas-tools', 'facter']:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
    }
  }

  # Remove unnecessary packages
  package { ['cloud-init', 'tasksel']:
    ensure => purged,
  }

  # Remove unnecessary files
  file { '/boot/firmware/user-data':
    ensure  => absent,
    require => Package['cloud-init'],
  }

  # Disable service
  service { 'puppet':
    ensure => undef,
    enable => false,
  }

  # Create drop in for services target
  if ($basic_settings_enable) {
    basic_settings::systemd_drop_in { 'puppet_dependency':
      target_unit => "${basic_settings::cluster_id}-system.target",
      unit        => {
        'Wants'   => 'puppet.service',
      },
      require     => Basic_settings::Systemd_target["${basic_settings::cluster_id}-system"],
    }
  }

  # Check if monitoring is enabled
  if ($monitoring_enable) {
    # Set unit
    $unit = {
      'OnFailure' => 'notify-failed@%i.service',
    }

    # Create service check
    if ($monitoring_package != 'none') {
      basic_settings::monitoring_custom { 'puppet_agent':
        content  => template('basic_settings/monitoring/puppet/check_agent'),
        friendly => 'Puppet Agent',
        timeout  => 60,
        interval => 600,
      }
    }
  } else {
    # Leave unit failure hooks empty when monitoring is unavailable.
    $unit = {}
  }

  # Apply Puppet service settings only when systemd is managed.
  if ($systemd_enable) {
    # Create drop in for puppet service
    basic_settings::systemd_drop_in { 'puppet_settings':
      target_unit => 'puppet.service',
      unit        => $unit,
      service     => {
        'Nice'        => 19,
        'LimitNOFILE' => 10000,
      },
    }

    # Create systemd puppet clean bucket service
    basic_settings::systemd_service { 'puppet-clean-filebucket':
      description => 'Clean puppet filebucket service',
      service     => {
        'ExecStart'               => "/usr/bin/find ${cache_dir}/clientbucket/ -type f -mtime +14 -atime +14 -delete", # lint:ignore:140chars Last dir separator (/) very important
        'LockPersonality'         => 'true',
        'MemoryDenyWriteExecute'  => 'true',
        'Nice'                    => '19',
        'NoNewPrivileges'         => 'true',
        'PrivateDevices'          => 'true',
        'PrivateTmp'              => 'true',
        'ProtectClock'            => 'true',
        'ProtectHome'             => 'true',
        'ProtectHostname'         => 'true',
        'ProtectControlGroups'    => 'true',
        'ProtectKernelLogs'       => 'true',
        'ProtectKernelModules'    => 'true',
        'ProtectKernelTunables'   => 'true',
        'ProtectSystem'           => 'full',
        'RestrictSUIDSGID'        => 'true',
        'SystemCallArchitectures' => 'native',
        'Type'                    => 'oneshot',
        'UMask'                   => '0077',
        'User'                    => 'root',
      },
      unit        => $unit,
    }

    # Schedule filebucket cleanup through the shared timer infrastructure when available.
    if ($basic_settings_enable) {
      # Create systemd puppet server clean reports timer
      basic_settings::systemd_timer { 'puppet-clean-filebucket':
        description        => 'Clean puppet filebucket timer',
        monitoring_enable  => $monitoring_enable,
        monitoring_package => $monitoring_package,
        timer              => {
          'OnCalendar' => '*-*-* 10:00',
        },
      }

      # Create drop in for services target
      basic_settings::systemd_drop_in { 'puppet_clean_filebucket_dependency':
        target_unit => "${basic_settings::cluster_id}-helpers.target",
        unit        => {
          'BindsTo'   => 'puppet-clean-filebucket.timer',
        },
        require     => Basic_settings::Systemd_target["${basic_settings::cluster_id}-helpers"],
      }
    } else {
      # Create systemd puppet server clean reports timer
      basic_settings::systemd_timer { 'puppet-clean-filebucket':
        description        => 'Clean puppet filebucket timer',
        monitoring_enable  => $monitoring_enable,
        monitoring_package => $monitoring_package,
        state              => 'running',
        timer              => {
          'OnCalendar' => '*-*-* 10:00',
        },
      }
    }
  }

  # Exclude Puppet's own SSL-directory writes only when auditd is managed.
  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'puppet_exclude':
      rules => [
        "-a never,exit -F arch=b32 -S all -F dir=${agent_etc_dir}/ssl -F perm=wa -F exe=${ruby_bin}",
        "-a never,exit -F arch=b64 -S all -F dir=${agent_etc_dir}/ssl -F perm=wa -F exe=${ruby_bin}",
      ],
      order => 2,
    }
  }

  # Do only the next steps when we are puppet server
  if ($server_enable) {
    # Install package
    package { $server_package:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Remove other package
    case $server_package {
      'openvox-server': {
        package { ['puppet-master', 'puppetserver']:
          ensure  => purged,
          require => Package[$server_package],
        }
      }
      'puppetserver': {
        package { ['openvox-server', 'puppet-master']:
          ensure  => purged,
          require => Package[$server_package],
        }
      }
      'puppet-master': {
        package { ['openvox-server', 'puppetserver']:
          ensure  => purged,
          require => Package[$server_package],
        }
      }
      default: {
        # Other server packages have no known conflicting package set to remove.
      }
    }

    # Disable service
    service { $server_service:
      ensure  => undef,
      enable  => false,
      require => Package[$server_package],
    }

    # Create drop in for services target
    if ($basic_settings_enable) {
      basic_settings::systemd_drop_in { "${server_service}_dependency":
        target_unit => "${basic_settings::cluster_id}-system.target",
        unit        => {
          'Wants'   => "${server_service}.service",
        },
        require     => Basic_settings::Systemd_target["${basic_settings::cluster_id}-system"],
      }
    }

    # Create service check
    if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
      basic_settings::monitoring_service { 'puppetserver':
        services => [$server_service],
      }
    }

    # Create puppet dirs
    file { $require_dirs:
      ensure  => directory,
      mode    => '0700',
      owner   => 'puppet',
      group   => 'puppet',
      require => Package[$server_package],
    }

    # Create symlink
    file { 'puppet_reports_symlink':
      ensure  => 'link',
      owner   => 'root',
      group   => 'root',
      path    => "${server_var_dir}/reports",
      target  => $server_report_dir,
      force   => true,
      require => File[$server_report_dir],
    }

    # Check if we have systemd
    if (defined(Package['systemd'])) {
      # Create env file
      file { '/etc/default/puppetserver':
        ensure  => file,
        mode    => '0600',
        owner   => 'puppet',
        group   => 'puppet',
        content => template('basic_settings/puppet/environment'),
        notify  => Service[$server_service],
      }

      # Create drop in for puppet x service
      basic_settings::systemd_drop_in { "${server_service}_settings":
        target_unit => "${server_service}.service",
        unit        => {
          'OnFailure' => 'notify-failed@%i.service',
        },
        service     => {
          'Nice'  => '-8',
          'UMask' => '0077',
        },
      }

      # Create systemd puppet x clean reports service
      basic_settings::systemd_service { "${server_service}-clean-reports":
        description => "Clean ${server_service} reports service",
        service     => {
          'ExecStart'               => "/usr/bin/find ${server_var_dir}/reports/ -type f -name '*.yaml' -ctime +1 -delete", # lint:ignore:140chars Last dir separator (/) very important
          'LockPersonality'         => 'true',
          'MemoryDenyWriteExecute'  => 'true',
          'Nice'                    => '19',
          'NoNewPrivileges'         => 'true',
          'PrivateDevices'          => 'true',
          'PrivateTmp'              => 'true',
          'ProtectClock'            => 'true',
          'ProtectHome'             => 'true',
          'ProtectHostname'         => 'true',
          'ProtectControlGroups'    => 'true',
          'ProtectKernelLogs'       => 'true',
          'ProtectKernelModules'    => 'true',
          'ProtectKernelTunables'   => 'true',
          'ProtectSystem'           => 'full',
          'RestrictSUIDSGID'        => 'true',
          'SystemCallArchitectures' => 'native',
          'Type'                    => 'oneshot',
          'UMask'                   => '0077',
          'User'                    => 'puppet',
        },
        unit        => $unit,
      }

      # Schedule server report cleanup through the shared timer infrastructure when available.
      if ($basic_settings_enable) {
        # Create systemd puppet x clean reports timer
        basic_settings::systemd_timer { "${server_service}-clean-reports":
          description        => "Clean ${server_service} reports timer",
          monitoring_enable  => $monitoring_enable,
          monitoring_package => $monitoring_package,
          timer              => {
            'OnCalendar' => '*-*-* 10:00',
          },
        }

        # Create drop in for services target
        basic_settings::systemd_drop_in { "${server_service}_clean_reports_dependency":
          target_unit => "${basic_settings::cluster_id}-helpers.target",
          unit        => {
            'BindsTo'   => "${server_service}-clean-reports.timer",
          },
          require     => Basic_settings::Systemd_target["${basic_settings::cluster_id}-helpers"],
        }
      } else {
        # Create systemd puppet x clean reports timer
        basic_settings::systemd_timer { "${server_service}-clean-reports":
          description        => "Clean ${server_service} reports timer",
          monitoring_enable  => $monitoring_enable,
          monitoring_package => $monitoring_package,
          state              => 'running',
          timer              => {
            'OnCalendar' => '*-*-* 10:00',
          },
        }
      }

      # Create drop in for puppet service
      basic_settings::systemd_drop_in { "puppet_${server_service}_dependency":
        target_unit => 'puppet.service',
        unit        => {
          'After'   => "${server_service}.service",
          'BindsTo' => "${server_service}.service",
        },
      }
    }

    # Setup audit rules
    if (defined(Package['auditd'])) {
      basic_settings::security_audit { 'puppet_general':
        rules => [
          "-a always,exit -F arch=b32 -F dir=${agent_etc_dir}/ssl -F perm=wa -F key=puppet_ssl",
          "-a always,exit -F arch=b64 -F dir=${agent_etc_dir}/ssl -F perm=wa -F key=puppet_ssl",
          "-a always,exit -F arch=b32 -F dir=${package_etc_dir}/code -F perm=r -F auid!=unset -F key=puppet_code",
          "-a always,exit -F arch=b64 -F dir=${package_etc_dir}/code -F perm=r -F auid!=unset -F key=puppet_code",
          "-a always,exit -F arch=b32 -F dir=${package_etc_dir}/code -F perm=wa -F key=puppet_code",
          "-a always,exit -F arch=b64 -F dir=${package_etc_dir}/code -F perm=wa -F key=puppet_code",
        ],
      }
    }
  } elsif (defined(Package['auditd'])) {
    basic_settings::security_audit { 'puppet_general':
      rules => [
        "-a always,exit -F arch=b32 -F dir=${agent_etc_dir}/ssl -F perm=wa -F key=puppet_ssl",
        "-a always,exit -F arch=b64 -F dir=${agent_etc_dir}/ssl -F perm=wa -F key=puppet_ssl",
      ],
    }
  }
}
