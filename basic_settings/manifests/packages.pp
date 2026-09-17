# @summary Manages APT policy, unattended upgrades, package hygiene, and package audit rules.
#
# This class installs core package-management tooling, removes desktop/update helpers that are not wanted on the target
# server profile, manages APT, apt-listchanges, needrestart, and unattended-upgrades configuration, optionally removes
# snapd, wires apt timers into systemd monitoring, and adds audit rules for package-management commands.
#
# @example Manage default package policy
#   include basic_settings::packages
#
# @example Allow unattended reboots and block an extra package
#   class { 'basic_settings::packages':
#     unattended_upgrades_reboot               => true,
#     unattended_upgrades_block_packages_extra => ['example-app'],
#   }
#
# @param antivirus_package
#   Optional antivirus integration name used for package-specific needrestart exceptions.
#
# @param config_dir_enable
#   Purges and owns `/etc/apt/apt.conf.d` when `true`.
#
# @param ip_version
#   Selects whether generated APT settings should force IPv4-only behavior.
#
# @param listchanges_dir_enable
#   Purges and owns `/etc/apt/listchanges.conf.d` when `true`.
#
# @param mail_to
#   Recipient used by generated APT/listchanges settings. The default is `root`.
#
# @param needrestart_dir_enable
#   Purges and owns `/etc/needrestart/conf.d` when `true`.
#
# @param proxy_http
#   Optional HTTP proxy rendered into APT settings.
#
# @param proxy_https
#   Optional HTTPS proxy rendered into APT settings.
#
# @param server_fdqn
#   Fully qualified host name used in generated package-management settings.
#
# @param snap_enable
#   Installs snapd when `true`; purges snapd and related files when `false`.
#
# @param systemd_default_target
#   Optional default systemd target used by package-management templates.
#
# @param unattended_upgrades_block_packages
#   Optional replacement list of packages blocked from unattended upgrades.
#   `undef` uses the module default block list for service stacks.
#
# @param unattended_upgrades_block_packages_extra
#   Additional package patterns appended to the unattended-upgrades block list.
#
# @param unattended_upgrades_reboot
#   Controls whether unattended-upgrades may reboot the host automatically.
#
# @api public
class basic_settings::packages (
  Optional[String] $antivirus_package                        = undef,
  Boolean          $config_dir_enable                        = true,
  Enum['all', '4'] $ip_version                               = 'all',
  Boolean          $listchanges_dir_enable                   = true,
  String           $mail_to                                  = 'root',
  Boolean          $needrestart_dir_enable                   = true,
  Optional[String] $proxy_http                               = undef,
  Optional[String] $proxy_https                              = undef,
  String           $server_fdqn                              = $facts['networking']['fqdn'],
  Boolean          $snap_enable                              = false,
  Optional[String] $systemd_default_target                   = undef,
  Optional[Array]  $unattended_upgrades_block_packages       = undef,
  Array            $unattended_upgrades_block_packages_extra = [],
  Boolean          $unattended_upgrades_reboot               = false,
) {
  # Set some values
  $systemd_enable = defined(Package['systemd'])
  $monitoring_enable = defined(Class['basic_settings::monitoring'])

  # Get IP versions
  case $ip_version {
    '4': {
      # Force APT downloads over IPv4 on an IPv4-only host.
      $ip_force = '4'
    }
    default: {
      # Leave APT's IP-family selection unrestricted.
      $ip_force = undef
    }
  }

  # Try to get systemd default target
  if (defined(Class['basic_settings::systemd'])) {
    # Inherit the shared systemd target unless the caller supplied an explicit target.
    if ($systemd_default_target == undef) {
      # Place package maintenance under the central cluster target by default.
      $systemd_default_target_correct = "${basic_settings::systemd::cluster_id}-${basic_settings::systemd::default_target}"
    } else {
      # Preserve the explicitly supplied package-maintenance target.
      $systemd_default_target_correct = $systemd_default_target
    }
  } else {
    # Preserve the explicitly supplied package-maintenance target.
    $systemd_default_target_correct = $systemd_default_target
  }

  # Get correct list
  if ($unattended_upgrades_block_packages == undef) {
    # Exclude database servers and application runtimes from unattended upgrades by default.
    $unattended_upgrades_block_packages_correct = [
      'libmysql*',
      'mysql*',
      'nginx',
      'nodejs',
      'php*',
      'python*',
      'rabbitmq-server',
    ]
  } else {
    # Use the caller's unattended-upgrade exclusion list.
    $unattended_upgrades_block_packages_correct = $unattended_upgrades_block_packages
  }

  # Set unattended_upgrades
  $unattended_upgrades_block_packages_all = flatten($unattended_upgrades_block_packages_extra, $unattended_upgrades_block_packages_correct)
  $unattended_upgrades_reboot_str = bool2str($unattended_upgrades_reboot)

  # Install missing package-management tools before their dependent packages.
  ensure_packages(
    [
      'apt',
      'dpkg',
      'curl',
      'gnupg',
    ],
    {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    },
  )

  # Install package
  package { [
      'apt-listchanges',
      'ca-certificates',
      'debconf',
      'debian-archive-keyring',
      'debian-keyring',
      'dirmngr',
      'libssl-dev',
      'needrestart',
      'ucf',
      'unattended-upgrades',
    ]:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['apt'],
  }

  # Install APT transport HTTPS package
  if (!defined(Package['apt-transport-https'])) {
    package { 'apt-transport-https':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Set default rules
  $default_rules = [
    '# Software manager',
    '-a always,exit -F arch=b32 -F path=/usr/bin/dpkg -F perm=x -F auid!=unset -F key=software_mgmt',
    '-a always,exit -F arch=b64 -F path=/usr/bin/dpkg -F perm=x -F auid!=unset -F key=software_mgmt',
    '-a always,exit -F arch=b32 -F path=/usr/bin/apt -F perm=x -F auid!=unset -F key=software_mgmt',
    '-a always,exit -F arch=b64 -F path=/usr/bin/apt -F perm=x -F auid!=unset -F key=software_mgmt',
    '-a always,exit -F arch=b32 -F path=/usr/bin/apt-get -F perm=x -F auid!=unset -F key=software_mgmt',
    '-a always,exit -F arch=b64 -F path=/usr/bin/apt-get -F perm=x -F auid!=unset -F key=software_mgmt',
  ]

  # Check if we need snap
  if ($snap_enable) {
    # Audit user execution of the Snap package-management commands.
    $snap_rules = [
      '-a always,exit -F arch=b32 -F path=/usr/bin/snap -F perm=x -F auid!=unset -F key=software_mgmt',
      '-a always,exit -F arch=b64 -F path=/usr/bin/snap -F perm=x -F auid!=unset -F key=software_mgmt',
      '-a always,exit -F arch=b32 -F path=/usr/bin/snapctl -F perm=x -F auid!=unset -F key=software_mgmt',
      '-a always,exit -F arch=b64 -F path=/usr/bin/snapctl -F perm=x -F auid!=unset -F key=software_mgmt',
    ]
    package { 'snapd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    # Remove snap
    $snap_rules = []
    package { 'snapd':
      ensure => purged,
    }

    # Remove unnecessary snapd and unminimize files
    file { ['/etc/apt/apt.conf.d/20snapd.conf', '/etc/xdg/autostart/snap-userd-autostart.desktop']:
      ensure  => absent,
      require => Package['snapd'],
    }
  }

  # Remove unnecessary packages
  package { ['command-not-found', 'packagekit', 'update-notifier-common']:
    ensure => purged,
  }

  # Do extra steps when Ubuntu
  if ($facts['os']['name'] == 'Ubuntu') {
    # Install extra packages when Ubuntu
    package { 'update-manager-core':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Remove unnecessary snapd and unminimize files
    file { ['/usr/local/sbin/unminimize', '/etc/update-motd.d/60-unminimize']:
      ensure => absent,
    }

    # Remove man
    exec { 'packages_man_remove':
      command => '/usr/bin/rm /usr/bin/man',
      onlyif  => ['[ -e /usr/bin/man ]', '[ -e /etc/dpkg/dpkg.cfg.d/excludes ]'],
    }

    # Create list of packages that is suspicious
    $suspicious_packages = ['/usr/bin/do-release-upgrade']

    # Setup audit rules
    if (defined(Package['auditd'])) {
      basic_settings::security_audit { 'packages':
        rules                    => flatten($default_rules, $snap_rules),
        rule_suspicious_packages => $suspicious_packages,
      }
    }
  } else {
    # Create list of packages that is suspicious
    $suspicious_packages = []

    # Setup audit rules
    if (defined(Package['auditd'])) {
      basic_settings::security_audit { 'packages':
        rules => flatten($default_rules, $snap_rules),
      }
    }
  }

  # Setup audit rules to exclude APT
  basic_settings::security_audit { 'apt_exclude':
    rules => [
      '-a never,exit -F arch=b32 -F exe=/usr/bin/apt-config -F auid=unset',
      '-a never,exit -F arch=b64 -F exe=/usr/bin/apt-config -F auid=unset',
      '-a never,exit -F arch=b32 -F exe=/usr/lib/apt/apt-helper -F auid=unset',
      '-a never,exit -F arch=b64 -F exe=/usr/lib/apt/apt-helper -F auid=unset',
    ],
    order => 2,
  }

  # Setup APT config dir
  if ($config_dir_enable) {
    file { '/etc/apt/apt.conf.d':
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
    }
  }

  # Create APT settings
  $apt_settings_file = '/etc/apt/apt.conf.d/99-settings.conf'
  file { $apt_settings_file:
    ensure  => file,
    content => template('basic_settings/packages/settings.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => Package['coreutils', 'needrestart', 'unattended-upgrades'],
  }

  # Setup APT list changes dir
  if ($listchanges_dir_enable) {
    file { '/etc/apt/listchanges.conf.d':
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
    }
  }

  # Create APT list changes settings
  file { '/etc/apt/listchanges.conf.d/99-settings.conf':
    ensure  => file,
    content => template('basic_settings/packages/listchanges.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => Package['unattended-upgrades'],
  }

  # Setup needrestart dir
  if ($needrestart_dir_enable) {
    file { '/etc/needrestart/conf.d':
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
    }
  }

  # Create needrestart config
  file { '/etc/needrestart/conf.d/99-settings.conf':
    ensure  => file,
    content => template('basic_settings/packages/needrestart.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => Package['needrestart'],
  }

  # Setup virusscanner
  case $antivirus_package {
    'eset': {
      # Setup needrestart rules
      file { '/etc/needrestart/conf.d/eset_efs.conf':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        replace => false,
      }
    }
    default: {
      # Other selections do not install an antivirus integration.
    }
  }

  # Create service check
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    basic_settings::monitoring_custom { 'apt':
      content  => template('basic_settings/monitoring/check_apt'),
      friendly => 'APT',
      interval => 3600 # 1 hour
    }
  }

  # Set debconf readline
  debconf { 'packages_debconf_readline':
    package => 'debconf',
    item    => 'debconf/frontend',
    type    => 'select',
    value   => 'Readline',
  }

  # Check if we have systemd
  if ($systemd_enable) {
    # Keep APT automation enabled only when systemd owns these timers.
    service { ['apt-daily.timer', 'apt-daily-upgrade.timer']:
      ensure  => running,
      enable  => true,
      require => Package['systemd'],
    }

    # Reload systemd deamon
    exec { 'packages_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Create drop in for APT upgrade service
    basic_settings::systemd_drop_in { 'apt_daily_upgrade_settings':
      target_unit   => 'apt-daily-upgrade.timer',
      timer         => {
        'OnCalendar'         => ['', '*-*-* 2:00'],
        'RandomizedDelaySec' => 30,
      },
      daemon_reload => 'packages_systemd_daemon_reload',
    }

    # Attach APT failure notifications only when monitoring integration is available.
    if ($monitoring_enable) {
      # Create drop in for APT service
      basic_settings::systemd_drop_in { 'apt_daily_notify_failed':
        target_unit   => 'apt-daily.service',
        unit          => {
          'OnFailure' => 'notify-failed@%i.service',
        },
        daemon_reload => 'packages_systemd_daemon_reload',
      }

      # Create drop in for APT upgrade service
      basic_settings::systemd_drop_in { 'apt_daily_upgrade_notify_failed':
        target_unit   => 'apt-daily-upgrade.service',
        unit          => {
          'OnFailure' => 'notify-failed@%i.service',
        },
        daemon_reload => 'packages_systemd_daemon_reload',
      }
    }
  }

  # Check if logrotate package exists
  if (defined(Package['logrotate'])) {
    basic_settings::io_logrotate { 'alternatives':
      path           => '/var/log/alternatives.log',
      frequency      => 'monthly',
      compress_delay => true,
    }

    # Rotate APT transaction and terminal history together.
    basic_settings::io_logrotate { 'apt':
      path      => "/var/log/apt/term.log\n/var/log/apt/history.log",
      frequency => 'monthly',
    }

    # Delay dpkg log compression so recent package diagnostics remain directly readable.
    basic_settings::io_logrotate { 'dpkg':
      path           => '/var/log/dpkg.log',
      frequency      => 'monthly',
      compress_delay => true,
    }

    # Keep automatic upgrade, dpkg and shutdown logs on the same monthly rotation.
    basic_settings::io_logrotate { 'unattended-upgrades':
      path      => "/var/log/unattended-upgrades/unattended-upgrades.log\n/var/log/unattended-upgrades/unattended-upgrades-dpkg.log\n/var/log/unattended-upgrades/unattended-upgrades-shutdown.log", # lint:ignore:140chars
      frequency => 'monthly',
    }
  }
}
