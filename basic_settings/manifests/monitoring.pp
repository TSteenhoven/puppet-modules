# @summary Prepares shared monitoring plumbing and failure notifications.
#
# lint:ignore:140chars
# This class installs mail tooling for systemd failure notifications, writes the shared monitoring notification helper, and, when requested, prepares the OpenITCOCKPIT agent custom-check directory and `customchecks.ini`. Other modules use this class as the central source for monitoring package selection, notification mail, and sudoers-directory policy.
# lint:endignore
#
# @example Enable OpenITCOCKPIT custom checks without installing the agent package
#   class { 'basic_settings::monitoring':
#     package => 'openitcockpit',
#   }
#
# @param mail_package
#   Mail transport service installed and enabled for failure notifications. The default is `postfix`.
#
# @param mail_to
#   Default recipient address for the shared monitoring notification helper and systemd failure notification mail. The default is `root`.
#
# @param package
# lint:ignore:140chars
#   Monitoring integration to configure. `none` retires active Puppet-owned custom checks without deleting plugins; `openitcockpit` writes their configuration. Keep this class declared during retirement; an active systemd agent is restarted to discard cached checks.
# lint:endignore
#
# @param package_install
#   Installs and wires the `openitcockpit-agent` package when `true` and `package` is `openitcockpit`.
#
# @param server_fdqn
#   Fully qualified host name used in notification subjects. The default comes from Facter.
#
# @param sudoers_dir_enable
#   Mirrors the login sudoers.d ownership policy so generated monitoring sudoers snippets are named consistently with the rest of the host.
#
# @api public
class basic_settings::monitoring (
  String                        $mail_package       = 'postfix',
  String                        $mail_to            = 'root',
  Enum['none', 'openitcockpit'] $package            = 'none',
  Boolean                       $package_install    = false,
  String                        $server_fdqn        = $facts['networking']['fqdn'],
  Boolean                       $sudoers_dir_enable = false,
) {
  # Set some default values
  $systemd_enable = defined(Package['systemd'])
  $monitoring_notify_path = '/usr/local/lib/puppet/monitoring-notify'

  # Escape notification values for the generated helper and systemd shell command.
  $mail_to_shell = stdlib::shell_escape($mail_to)
  $monitoring_notify_path_shell = stdlib::shell_escape($monitoring_notify_path)
  $monitoring_mail_from_shell = stdlib::shell_escape("monitoring@${server_fdqn}")
  $systemd_mail_from_shell = stdlib::shell_escape("systemd@${server_fdqn}")

  # Pass the systemd instance as $0 so bash can quote it without systemd parsing shell escape sequences.
  $notify_failed_script = join([
      'LC_CTYPE=C systemctl status --full "$0" |',
      "${monitoring_notify_path_shell} -t ${mail_to_shell}",
      "-r ${systemd_mail_from_shell} \"Service \$0 failed on ${server_fdqn}\"",
  ], ' ')

  # Install package
  package { [$mail_package, 'mailutils']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Create script dir
  if (!defined(File['/usr/local/lib/puppet'])) {
    file { '/usr/local/lib/puppet':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755', # Important, not only root are executing this rule
    }
  }

  # Create shared monitoring notification helper
  file { $monitoring_notify_path:
    ensure  => file,
    content => template('basic_settings/monitoring/monitoring-notify'),
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => [File['/usr/local/lib/puppet'], Package['mailutils']],
  }

  # Do thing based on mail package
  case $mail_package {
    'postfix': {
      exec { 'monitoring_newaliases':
        command => '/usr/bin/newaliases',
        creates => '/etc/aliases.db',
      }
    }
    default: {
      # Other mail implementations do not use the managed aliases database.
    }
  }

  # Enable mail service
  service { $mail_package:
    ensure  => true,
    enable  => true,
    require => Package[$mail_package],
  }

  # Register the monitoring unit reload only when systemd is managed.
  if ($systemd_enable) {
    # Reload systemd deamon
    exec { 'monitoring_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create systemd service for notification
    basic_settings::systemd_service { 'notify-failed@':
      description   => 'Send systemd notifications to mail',
      service       => {
        'ExecStart'               => "/usr/bin/bash -c '${notify_failed_script}' %i",
        'LockPersonality'         => 'true',
        'MemoryDenyWriteExecute'  => 'true',
        'NoNewPrivileges'         => 'true',
        'PrivateDevices'          => 'true',
        'PrivateTmp'              => 'true',
        'ProtectClock'            => 'true',
        'ProtectHome'             => 'true',
        'ProtectHostname'         => 'true',
        'ProtectKernelLogs'       => 'true',
        'ProtectKernelModules'    => 'true',
        'ProtectKernelTunables'   => 'true',
        'ProtectSystem'           => 'full',
        'RestrictSUIDSGID'        => 'true',
        'SystemCallArchitectures' => 'native',
        'Type'                    => 'oneshot',
        'UMask'                   => '0077',
      },
      daemon_reload => 'monitoring_systemd_daemon_reload',
      enable        => false,
      require       => [Package[$mail_package], File[$monitoring_notify_path]],
    }

    # Create drop in for notify-failed service
    basic_settings::systemd_drop_in { "notify-failed_${mail_package}_dependency":
      target_unit   => 'notify-failed@',
      unit          => {
        'Wants' => "${mail_package}.service",
      },
      daemon_reload => 'monitoring_systemd_daemon_reload',
      require       => [Package[$mail_package], Basic_settings::Systemd_service['notify-failed@']],
    }
  }

  # Monitoring package 
  case $package {
    'openitcockpit': {
      # Check if we can install package
      if ($package_install) {
        # Install OpenITCockpit agent
        package { 'openitcockpit-agent':
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
        }

        # Check if we have systemd
        if ($systemd_enable) {
          # Disable service
          service { 'monitoring_service':
            ensure  => undef,
            name    => 'openitcockpit-agent',
            enable  => false,
            require => Package['openitcockpit-agent'],
          }

          # Create drop in for x target
          if (defined(Class['basic_settings::systemd'])) {
            basic_settings::systemd_drop_in { 'openitcockpit_agent_dependency':
              target_unit   => "${basic_settings::systemd::cluster_id}-services.target",
              unit          => {
                'BindsTo'   => 'openitcockpit-agent.service',
              },
              daemon_reload => 'monitoring_systemd_daemon_reload',
              require       => Basic_settings::Systemd_target["${basic_settings::systemd::cluster_id}-services"],
            }
          }

          # Create drop in for ncpa service
          basic_settings::systemd_drop_in { 'openitcockpit_agent_settings':
            target_unit   => 'openitcockpit-agent.service',
            unit          => {
              'OnFailure' => 'notify-failed@%i.service',
            },
            service       => {
              'PrivateDevices' => 'true',
              'PrivateTmp'     => 'true',
              'ProtectHome'    => 'true',
              'ProtectSystem'  => 'full',
              'ReadWritePaths' => '/etc/openitcockpit-agent',
              'UMask'          => '0077',
            },
            daemon_reload => 'monitoring_systemd_daemon_reload',
            require       => Package['openitcockpit-agent'],
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
        mode    => '0755', # Important
        owner   => 'root',
        group   => 'root',
        require => File['monitoring_location'],
      }

      # Create config config
      concat { '/etc/openitcockpit-agent/customchecks.ini':
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => File['monitoring_location'],
      }

      # An externally installed agent need not have a Service resource until its owning class is evaluated.
      Concat['/etc/openitcockpit-agent/customchecks.ini'] ~> Service <| title == 'monitoring_service' |>

      # Create fragment 
      concat::fragment { 'monitoring_customchecks_default':
        target  => '/etc/openitcockpit-agent/customchecks.ini',
        content => "# Managed by puppet\n[default]\n",
        order   => '01',
      }
    }
    default: {
      # Retire only this repository-owned registry, without creating directories or purging other plugins.
      # An independently declared agent may subsequently rebuild an empty registry through concat.
      exec { 'monitoring_retire_customchecks':
        command  => '/usr/bin/printf "# Managed by puppet\n[default]\n" > /etc/openitcockpit-agent/customchecks.ini',
        onlyif   => '/usr/bin/grep -qx "# Managed by puppet" /etc/openitcockpit-agent/customchecks.ini && /usr/bin/grep -qx "enabled = true" /etc/openitcockpit-agent/customchecks.ini', # lint:ignore:140chars
        provider => shell,
      }
      Exec['monitoring_retire_customchecks'] -> Concat <| title == '/etc/openitcockpit-agent/customchecks.ini' |>

      # Retirement may follow removal of the agent Service resource, so refresh only an already running systemd backend.
      exec { 'monitoring_retire_customchecks_reload':
        command     => '/usr/bin/systemctl try-restart openitcockpit-agent.service',
        onlyif      => '/usr/bin/test -x /usr/bin/systemctl && /usr/bin/systemctl is-active --quiet openitcockpit-agent.service',
        provider    => shell,
        refreshonly => true,
        subscribe   => Exec['monitoring_retire_customchecks'],
      }
    }
  }

  # Validate the active systemd configuration from the default target.
  if ($systemd_enable) {
    basic_settings::monitoring_custom { 'systemd_config':
      friendly => 'Systemd config',
      source   => 'puppet:///modules/basic_settings/monitoring/check_systemd_config',
      timeout  => 60,
    }
  }

  # Create service check
  basic_settings::monitoring_service { 'mail':
    services => [$mail_package],
  }
}
