class basic_settings::packages (
  Boolean $config_dir_enable                          = true,
  Boolean $listchanges_dir_enable                     = true,
  Array   $unattended_upgrades_block_extra_packages   = [],
  Array   $unattended_upgrades_block_packages         = [
    'libmysql*',
    'mysql*',
    'nginx',
    'nodejs',
    'php*',
  ],
  String  $server_fdqn                                = $facts['networking']['fqdn'],
  Boolean $snap_enable                                = false,
  String  $mail_to                                    = 'root',
  Boolean $needrestart_dir_enable                     = true
) {
  # Install apt package
  if (!defined(Package['apt'])) {
    package { 'apt':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install dpkg package
  if (!defined(Package['dpkg'])) {
    package { 'dpkg':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Install package
  package { [
      'apt-listchanges',
      'apt-transport-https',
      'ca-certificates',
      'curl',
      'debconf',
      'debian-archive-keyring',
      'debian-keyring',
      'dirmngr',
      'gnupg',
      'libssl-dev',
      'needrestart',
      'ucf',
      'unattended-upgrades',
    ]:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Package['apt'],
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

  # Set unattended_upgrades
  $unattended_upgrades_block_all_packages = flatten($unattended_upgrades_block_extra_packages, $unattended_upgrades_block_packages);

  # Check if we need snap
  if (!$snap_enable) {
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
  } else {
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
  }

  # Remove unnecessary packages
  package { 'packagekit':
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

  # Setup APT config dir
  if ($config_dir_enable) {
    file { '/etc/apt/apt.conf.d':
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
    }
  }

  # Create APT settings
  file { '/etc/apt/apt.conf.d/99-settings.conf':
    ensure  => file,
    content => template('basic_settings/packages/settings.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => [Package['coreutils'], Package['needrestart'], Package['unattended-upgrades']],
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
      mode    => '0700',
    }
  }

  # Create APT list chanes settings
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
      mode    => '0700',
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

  # Ensure that apt-daily timers is always running
  service { ['apt-daily.timer', 'apt-daily-upgrade.timer']:
    ensure  => running,
    enable  => true,
    require => Package['systemd'],
  }

  # Set debconf readline
  debconf { 'packages_debconf_readline':
    package => 'debconf',
    item    => 'debconf/frontend',
    type    => 'select',
    value   => 'Readline',
  }

  if (defined(Package['systemd']) and defined(Class['basic_settings::message'])) {
    # Reload systemd deamon
    exec { 'packages_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

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

  # Check if logrotate package exists
  if (defined(Package['logrotate'])) {
    basic_settings::io_logrotate { 'alternatives':
      path           => '/var/log/alternatives.log',
      frequency      => 'monthly',
      compress_delay => true,
    }
    basic_settings::io_logrotate { 'apt':
      path      => "/var/log/apt/term.log\n/var/log/apt/history.log",
      frequency => 'monthly',
    }
    basic_settings::io_logrotate { 'dpkg':
      path           => '/var/log/dpkg.log',
      frequency      => 'monthly',
      compress_delay => true,
    }
    basic_settings::io_logrotate { 'unattended-upgrades':
      path      => "/var/log/unattended-upgrades/unattended-upgrades.log\n/var/log/unattended-upgrades/unattended-upgrades-dpkg.log\n/var/log/unattended-upgrades/unattended-upgrades-shutdown.log",
      frequency => 'monthly',
    }
  }
}
