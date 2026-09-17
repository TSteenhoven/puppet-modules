# @summary Manages auditd, AppArmor, AIDE defaults, and security monitoring hooks.
#
# This class installs and enables auditd and AppArmor, writes auditd and AIDE configuration files, registers baseline
# audit rules, creates the `auditmail` systemd service and timer, and adds monitoring checks when the shared monitoring
# class is active. Antivirus integrations can add audit exclusions and monitoring plugins.
#
# @example Enable the default security baseline
#   include basic_settings::security
#
# @param antivirus_package
#   Optional antivirus integration name. Supported values add package-specific audit exclusions and monitoring checks.
#
# @param mail_to
#   Recipient used by security notification templates. The default is `root`.
#
# @param server_fdqn
#   Fully qualified host name used by generated security notification content.
#
# @api public
class basic_settings::security (
  Optional[String] $antivirus_package = undef,
  String           $mail_to           = 'root',
  String           $server_fdqn       = $facts['networking']['fqdn'],
) {
  # Set some values
  $systemd_enable = defined(Package['systemd'])
  $monitoring_enable = defined(Class['basic_settings::monitoring'])

  # Escape notification values for generated shell templates.
  $mail_to_shell = stdlib::shell_escape($mail_to)
  $audit_mail_from_shell = stdlib::shell_escape("audit@${server_fdqn}")
  $server_fdqn_shell = stdlib::shell_escape($server_fdqn)

  # Check if auditd package is not defined
  if (!defined(Package['auditd'])) {
    package { 'auditd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install default security packages
  package { ['aide-common', 'apparmor', 'pwgen']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Enable apparmor service
  service { 'apparmor':
    ensure  => true,
    enable  => true,
    require => Package['apparmor'],
  }

  # Enable auditd service
  if (!defined(Service['auditd'])) {
    service { 'auditd':
      ensure  => true,
      enable  => true,
      require => Package['auditd'],
    }
  }

  # Setup monitoring
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    # Audit and ESET share these shell tools; systemd applies only to the selected inspection path.
    $monitoring_packages = concat(['coreutils', 'dash', 'grep', 'mawk', 'procps', 'sed'], $systemd_enable ? {
      true    => ['systemd'],
      default => [],
    })
    ensure_packages($monitoring_packages, {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    })

    # Include auditd alongside the shared shell tools for the audit check.
    $audit_required_packages = concat(
      $monitoring_packages,
      ['auditd'],
    )

    # Register the check after its runtime packages.
    basic_settings::monitoring_custom { 'audit':
      content  => template('basic_settings/monitoring/check_audit'),
      timeout  => 300,
      interval => 600,
      require  => Package[$audit_required_packages],
    }
  }

  # Setup virusscanner
  case $antivirus_package {
    'eset': {
      # Setup audit rules
      basic_settings::security_audit { 'antivirus':
        rules => [
          '-a never,exit -F exe=/opt/eset/efs/lib/odfeeder',
          '-a never,exit -F exe=/opt/eset/efs/lib/schedd',
          '-a never,exit -F exe=/opt/eset/efs/lib/utild',
        ],
        order => 2,
      }

      # Setup monitoring
      if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
        # Register the check after its runtime packages.
        basic_settings::monitoring_custom { 'antivirus':
          friendly => 'ESET Server Security',
          content  => template('basic_settings/monitoring/check_eset'),
          timeout  => 60,
          require  => Package[$monitoring_packages],
        }
      }
    }
    default: {
      # Other selections do not configure an antivirus integration.
    }
  }

  # Create service check
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    basic_settings::monitoring_service { 'apparmor': }
  }

  # Create auditd config file */
  file { '/etc/audit/auditd.conf':
    ensure  => file,
    content => template('basic_settings/security/auditd.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Service['auditd'],
  }

  # Create rules dir
  if (!defined(File['/etc/audit/rules.d'])) {
    file { '/etc/audit/rules.d':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      recurse => true,
      force   => true,
      purge   => true,
      mode    => '0600',
    }
  }

  # Create default audit rule file */
  file { '/etc/audit/rules.d/audit.rules':
    ensure  => file,
    content => template('basic_settings/security/audit.rules'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Service['auditd'],
    require => File['/etc/audit/rules.d'],
  }

  # Create systemd exclude rules
  if (defined(Package['systemd-cron'])) {
    basic_settings::security_audit { 'systemd_exclude':
      rules   => [
        '-a never,exit -F arch=b32 -F exe=/usr/bin/systemd-tmpfiles -F auid=unset',
        '-a never,exit -F arch=b64 -F exe=/usr/bin/systemd-tmpfiles -F auid=unset',
      ],
      order   => 2,
      require => File['/etc/audit/rules.d'],
    }
  }

  # Create main audit rule file */
  file { '/etc/audit/rules.d/10-main.rules':
    ensure  => file,
    content => template('basic_settings/security/main.rules'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Service['auditd'],
    require => File['/etc/audit/rules.d'],
  }

  # Create default audit file */
  file { '/usr/local/sbin/auditmail':
    ensure  => file,
    content => template('basic_settings/security/auditmail'),
    owner   => 'root',
    group   => 'root',
    mode    => '0700', # Only root
    notify  => Service['auditd'],
  }

  # Check if systemd and message class exists
  if ($systemd_enable) {
    # Create systemctl daemon reload
    exec { 'security_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create unit
    if ($monitoring_enable) {
      # Route unit failures through the configured monitoring notification service.
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }

      # Create drop in for apparmor service
      basic_settings::systemd_drop_in { 'apparmor_notify_failed':
        target_unit   => 'apparmor.service',
        unit          => $unit,
        daemon_reload => 'security_systemd_daemon_reload',
        require       => Package['apparmor'],
      }
    } else {
      # Leave unit failure hooks empty when monitoring is unavailable.
      $unit = {}
    }

    # Create drop in for auditd service
    basic_settings::systemd_drop_in { 'auditd_settings':
      target_unit   => 'auditd.service',
      unit          => $unit,
      service       => {
        'PrivateTmp'  => 'true',
        'ProtectHome' => 'false', # Important for monitoring home dirs
        'UMask'       => '0027', # auditd.conf uses log_group=adm, so keep audit logs group-readable.
      },
      daemon_reload => 'security_systemd_daemon_reload',
      require       => Package['auditd'],
    }

    # Create systemd service
    basic_settings::systemd_service { 'auditmail':
      description   => 'Audit mail service',
      unit          => $unit,
      service       => {
        'ExecStart'               => '/usr/local/sbin/auditmail',
        'LockPersonality'         => 'true',
        'MemoryDenyWriteExecute'  => 'true',
        'Nice'                    => '-20', # Important process
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
      daemon_reload => 'security_systemd_daemon_reload',
      enable        => false,
    }

    # Create systemd timer
    basic_settings::systemd_timer { 'auditmail':
      description   => 'Audit mail timer',
      state         => 'running',
      timer         => {
        'OnCalendar' => '*-*-* 0:30',
      },
      daemon_reload => 'security_systemd_daemon_reload',
    }

    # Create default aide file */
    file { '/etc/default/aide':
      ensure  => file,
      content => template('basic_settings/security/aide'),
      owner   => 'root',
      group   => 'root',
      mode    => '0700', # Only root
    }
  }
}
