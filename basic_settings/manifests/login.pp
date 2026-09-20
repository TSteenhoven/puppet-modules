# @summary Manages login policy, shell idle timeouts, sudo defaults, PAM hooks, MOTD, and getty state.
#
# This class installs core login tooling, creates the `wheel` group, manages sudoers and PAM configuration, controls
# console getty availability, and adds audit coverage for login, PAM, sudoers, and optional vulnerability-scanner
# exceptions. These changes affect interactive access and should be reviewed carefully on existing hosts with local sudo
# customizations.
#
# Console selection comes from the read-only agent fact `console_gettys`, using getty.target dependencies.
# Puppet manages the selected text and serial instances during each run and preserves their existing boot links.
# This does not block activation by systemd between Puppet runs or during boot. Before enabling a kiosk host, verify
# that the configured consoles are usable and do not conflict with its graphical session. Review getty-static.service
# separately if its local configuration starts additional consoles outside getty.target dependencies.
# Discovery errors fail compilation; a successful empty selection is valid.
#
# The shell policy in `/etc/profile.d/tmout.sh` sets a readonly, exported `TMOUT` only when an interactive shell loads
# it. Non-interactive shells skip this initialization. Bash enforces the idle timeout; Dash does not enforce an idle
# timeout through `TMOUT`.
#
# Standard Bash login routes on Debian and Ubuntu load `/etc/profile.d` through `/etc/profile`, including console and
# interactive SSH logins, `su -`, and `sudo -i`. Verify that custom shells and profiles load the managed policy and
# support its timeout behavior.
#
# Updating this timeout does not terminate existing sessions or restart SSH. Reloading the profile preserves an existing
# readonly value without an error; open a new login shell to apply a changed value.
#
# Scripts started from an interactive shell can inherit `TMOUT`. Bash also uses it as the default timeout for `read` and
# for terminal input in `select`; set an explicit `read -t` timeout or remove `TMOUT` from the child script's own
# environment when needed.
#
# @see https://manpages.ubuntu.com/manpages/jammy/man1/bash.1.html Bash TMOUT and shell startup behavior
#
# @example Manage the default hardened login profile
#   include basic_settings::login
#
# @example Preserve an existing sudoers.d tree
#   class { 'basic_settings::login':
#     sudoers_dir_enable => false,
#   }
#
# @param environment
#   Server environment passed by `basic_settings::environment`, independent of the Puppet code environment; defaults to
#   `production`.
#   Selects the shell idle timeout: `production` uses 900 seconds; every other value uses 1800 seconds.
#   Also used in generated login messages and templates.
#
# @param getty_enable
#   Keeps configured text and serial console gettys running when `true`, or stopped when `false`, during Puppet runs.
#   The default is `false`. Boot links remain unchanged; automatic activation outside Puppet runs is not blocked.
#   `gui_mode => 'kiosk'` forces the effective value to `true`. Requires the agent-side `console_gettys` fact.
#
# @param gui_mode
#   Selects GUI-related login behavior. `none` keeps the server minimal, `kiosk` enables getty and installs related
#   session packages, and `adwaita-icon` is handled by the parent class for icon package selection.
#
# @param hostname
#   Hostname used by generated login templates. The default comes from Facter.
#
# @param mail_to
#   Mail recipient used by notification templates and related login hooks. The default is `root`.
#
# @param server_fdqn
#   Fully qualified server name used in generated messages. The default comes from Facter.
#
# @param sudoers_banner_text
#   Text written to `/etc/sudoers.lecture` and shown during sudo prompts.
#
# @param sudoers_dir_enable
#   When `true`, manages `/etc/sudoers.d` as a purged Puppet-owned directory.
#   Set this to `false` on hosts where existing sudoers snippets must remain.
#
# @param vulnerabilities_package
#   Optional vulnerability scanner integration name. Currently only recognized values are handled by explicit case
#   branches.
#
# @param vulnerabilities_user
#   User account for the vulnerability scanner integration. It is only used when `vulnerabilities_package` is also set.
#
# @api public
class basic_settings::login (
  String                                $environment             = 'production',
  Boolean                               $getty_enable            = false,
  Enum['none', 'kiosk', 'adwaita-icon'] $gui_mode                = 'none',
  String                                $hostname                = $facts['networking']['hostname'],
  String                                $mail_to                 = 'root',
  String                                $server_fdqn             = $facts['networking']['fqdn'],
  String                                $sudoers_banner_text     = "WARNING: You are running this command with elevated privileges.\nThis action is registered and sent to the server administrator(s). Unauthorized access will be fully investigated and reported to law enforcement authorities.", # lint:ignore:140chars
  Boolean                               $sudoers_dir_enable      = false,
  Optional[String]                      $vulnerabilities_package = undef,
  Optional[String]                      $vulnerabilities_user    = undef,
) {
  # Remove unnecessary packages
  package { ['tmux', 'xdg-user-dirs', 'xauth', 'x11-utils']:
    ensure => purged,
  }

  # Install packages
  package { ['login', 'screen', 'libpam-modules', 'nscd']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Install the shared packages required for login configuration and service management.
  ensure_packages(
    ['libpam-runtime', 'systemd', 'sudo'],
    {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    },
  )

  # Install wtmpdb packages
  case $facts['os']['release']['major'] {
    '13': {
      # Share the login database packages with profile ordering.
      $wtmpdb_packages = ['wtmpdb', 'libpam-wtmpdb']
      package { $wtmpdb_packages:
        ensure          => installed,
        install_options => ['--no-install-recommends', '--no-install-suggests'],
      }
      $mesg_disable = true
      $require = Package[$wtmpdb_packages]
    }
    default: {
      # Retain mesg n in login profiles on the legacy path without wtmpdb dependencies.
      $mesg_disable = false
      $require = undef
    }
  }

  # Create group wheel
  group { 'wheel':
    system => true,
  }

  # Create list of packages that is suspicious
  $suspicious_packages = ['/usr/bin/chage', '/usr/bin/sudo', '/usr/bin/last', '/usr/sbin/pam-auth-update']

  # Escape notification values for generated shell templates.
  $mail_to_shell = stdlib::shell_escape($mail_to)
  $audit_mail_from_shell = stdlib::shell_escape("audit@${server_fdqn}")
  $server_fdqn_shell = stdlib::shell_escape($server_fdqn)

  # Setup GUI mode
  case $gui_mode {
    'kiosk': {
      # Enable console and session services required by the graphical login path.
      $getty_correct = true
      $polkitd_enable = true
      $session_migration_enable = true
    }
    default: {
      # Honor console login settings without enabling graphical session integration.
      $getty_correct = $getty_enable
      $polkitd_enable = false
      $session_migration_enable = false
    }
  }

  # Keep polkit installed only when local authorization services are requested.
  if ($polkitd_enable) {
    # Install polkitd package
    package { 'polkitd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    # Remove polkitd package
    package { 'polkitd':
      ensure => purged,
    }
  }

  # Keep session migration tools only when the selected login environment needs them.
  if ($session_migration_enable) {
    # Install session-migration package
    package { 'session-migration':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    # Remove session-migration package
    package { 'session-migration':
      ensure => purged,
    }
  }

  # Ensure that nscd is always running
  service { 'nscd':
    ensure  => running,
    enable  => true,
    require => Package['nscd'],
  }

  # Create script dir
  if (!defined(File['/usr/local/lib/puppet'])) {
    file { '/usr/local/lib/puppet':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755' # Important, not only root are executing this rule
    }
  }

  # Create su trigger
  $su_notify_path = '/usr/local/lib/puppet/su-notify'
  file { $su_notify_path:
    ensure  => file,
    content => template('basic_settings/login/pam/notify'),
    owner   => 'root',
    group   => 'root',
    mode    => '0755', # Important, not only root are executing this rule
    require => File['/usr/local/lib/puppet'],
  }

  # Run command when PAM file is changed
  exec { 'login_pam_auth_update':
    command     => '/usr/sbin/pam-auth-update --package',
    refreshonly => true,
    require     => Package['libpam-runtime', 'systemd'],
  }

  # Setup pam common-session file
  file { '/usr/share/pam-configs/custom':
    ensure  => file,
    mode    => '0664',
    owner   => 'root',
    group   => 'root',
    content => template('basic_settings/login/pam/custom'),
    notify  => Exec['login_pam_auth_update'],
  }

  # Setup su pam config file
  file { '/etc/pam.d/su':
    ensure  => file,
    mode    => '0664',
    owner   => 'root',
    group   => 'root',
    content => template('basic_settings/login/pam/su'),
    require => File[$su_notify_path],
  }

  # Sudoers banner by password prompt
  file { '/etc/sudoers.lecture':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "${sudoers_banner_text}\n\n",
    require => Package['sudo'],
  }

  # Setup sudoers config file
  file { '/etc/sudoers':
    ensure  => file,
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
    content => template('basic_settings/login/sudoers'),
    require => File['/etc/sudoers.lecture'],
  }

  # Setup sudoers dir
  if ($sudoers_dir_enable) {
    file { '/etc/sudoers.d':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0440',
      purge   => true,
      recurse => true,
      force   => true,
      require => Package['sudo'],
    }
    $sudoers_prefix = ''
  } else {
    # Use the fallback sudoers prefix when no managed sudoers directory is available.
    $sudoers_prefix = 'z'
  }

  # Check if OS is Ubuntu
  if ($facts['os']['name'] == 'Ubuntu') {
    # Install packages
    package { 'update-motd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Disable motd news
    file { '/etc/default/motd-news':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => "ENABLED=0\n",
      require => Package['update-motd'],
    }

    # Ensure that motd-news is stopped
    service { 'motd-news.timer':
      ensure    => stopped,
      enable    => false,
      require   => File['/etc/default/motd-news'],
      subscribe => File['/etc/default/motd-news'],
    }

    # Set welcome header
    file { '/etc/update-motd.d/00-header':
      ensure  => file,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => template('basic_settings/login/motd/header'),
      notify  => Package['update-motd'],
    }
  }

  # Use the server environment already shared with login messages for the shell idle timeout.
  $tmout = $environment ? {
    'production' => 900,
    default      => 1800,
  }

  # Remove the legacy profile before installing its replacement, without purging other profile fragments.
  file { '/etc/profile.d/timeout.sh':
    ensure => absent,
  }

  # Every login user must be able to source this profile; only root may change it.
  file { '/etc/profile.d/tmout.sh':
    ensure  => file,
    content => template('basic_settings/login/tmout.sh'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => File['/etc/profile.d/timeout.sh'],
  }

  # Create profile trigger
  file { '/etc/profile.d/99-login-notify.sh':
    ensure  => file,
    content => template('basic_settings/login/login-notify.sh'),
    owner   => 'root',
    group   => 'root',
    mode    => '0755', # Important, not only root are executing this rule,
    require => $require,
  }

  # Check if we have vulnerabilities package and user
  if ($vulnerabilities_package != undef and $vulnerabilities_user != undef) {
    case $vulnerabilities_package {
      'rapid7': {
        # Create sudoers file
        file { "/etc/sudoers.d/${sudoers_prefix}90-vulnerabilities":
          ensure  => file,
          owner   => 'root',
          group   => 'root',
          mode    => '0440',
          content => "# Managed by puppet\nUser_Alias R7 = ${vulnerabilities_user}\nCmnd_Alias R7_BASH_CMD = /bin/bash, /bin/bash -c *\nR7 ALL=(ALL) ALL, NOMAIL: R7_BASH_CMD\n", # lint:ignore:140chars
          require => Package['sudo'],
        }

        # Setup audit rules
        basic_settings::security_audit { 'login_vulnerabilities':
          rules => [
            "-a never,exit -F arch=b32 -S connect -F exe=/bin/bash -F auid=${vulnerabilities_user}",
            "-a never,exit -F arch=b64 -S connect -F exe=/bin/bash -F auid=${vulnerabilities_user}",
            "-a never,exit -F arch=b32 -S connect -F exe=/usr/bin/bash -F auid=${vulnerabilities_user}",
            "-a never,exit -F arch=b64 -S connect -F exe=/usr/bin/bash -F auid=${vulnerabilities_user}",
          ],
          order => 2,
        }
      }
      default: {
        # Other selections do not install a vulnerability scanner.
      }
    }
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'login':
      rules                    => [
        '# Login',
        '-a always,exit -F arch=b32 -F path=/etc/login.defs -F perm=wa -F key=login',
        '-a always,exit -F arch=b64 -F path=/etc/login.defs -F perm=wa -F key=login',
        '-a always,exit -F arch=b32 -F path=/var/log/faillog -F perm=wa -F key=login',
        '-a always,exit -F arch=b64 -F path=/var/log/faillog -F perm=wa -F key=login',
        '-a always,exit -F arch=b32 -F path=/var/log/lastlog -F perm=wa -F key=login',
        '-a always,exit -F arch=b64 -F path=/var/log/lastlog -F perm=wa -F key=login',
        '-a always,exit -F arch=b32 -F path=/var/log/auth.log -F perm=wa -F key=login',
        '-a always,exit -F arch=b64 -F path=/var/log/auth.log -F perm=wa -F key=login',
        '# User configuration',
        '-a always,exit -F arch=b32 -F path=/etc/security/limits.conf -F perm=wa  -F key=limits',
        '-a always,exit -F arch=b64 -F path=/etc/security/limits.conf -F perm=wa  -F key=limits',
        '-a always,exit -F arch=b32 -F path=/etc/security/namespace.conf -F perm=wa -F key=namespace',
        '-a always,exit -F arch=b64 -F path=/etc/security/namespace.conf -F perm=wa -F key=namespace',
        '-a always,exit -F arch=b32 -F path=/etc/security/namespace.init -F perm=wa -F key=namespace',
        '-a always,exit -F arch=b64 -F path=/etc/security/namespace.init -F perm=wa -F key=namespace',
        '# PAM configuration',
        '-a always,exit -F arch=b32 -F dir=/etc/pam.d -F perm=wa -F key=pam',
        '-a always,exit -F arch=b64 -F dir=/etc/pam.d -F perm=wa -F key=pam',
        '-a always,exit -F arch=b32 -F path=/etc/security/pam_env.conf -F perm=wa -F key=pam',
        '-a always,exit -F arch=b64 -F path=/etc/security/pam_env.conf -F perm=wa -F key=pam',
        '# Sudoers configuration',
        '-a always,exit -F arch=b32 -F path=/etc/sudoers -F perm=r -F auid!=unset -F key=sudoers',
        '-a always,exit -F arch=b64 -F path=/etc/sudoers -F perm=r -F auid!=unset -F key=sudoers',
        '-a always,exit -F arch=b32 -F dir=/etc/sudoers.d -F perm=r -F auid!=unset -F key=sudoers',
        '-a always,exit -F arch=b64 -F dir=/etc/sudoers.d -F perm=r -F auid!=unset -F key=sudoers',
        '-a always,exit -F arch=b32 -F path=/etc/sudoers -F perm=wa -F key=sudoers',
        '-a always,exit -F arch=b64 -F path=/etc/sudoers -F perm=wa -F key=sudoers',
        '-a always,exit -F arch=b32 -F dir=/etc/sudoers.d -F perm=wa -F key=sudoers',
        '-a always,exit -F arch=b64 -F dir=/etc/sudoers.d -F perm=wa -F key=sudoers',
      ],
      rule_suspicious_packages => $suspicious_packages,
    }
  }

  # Keep legacy cleanup separate so it can be removed after rollout to every consumer.
  service { 'getty@tty\x2a.service':
    ensure   => stopped,
    enable   => false,
    provider => systemd,
    require  => Package['systemd'],
  }

  # Reload only when removing the old wildcard workaround; other getty drop-ins remain untouched.
  exec { 'login_systemd_daemon_reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    require     => Package['systemd'],
  }

  # Retire the drop-in that guarded the old wildcard instance.
  file { '/etc/systemd/system/getty@.service.d/getty_settings.conf':
    ensure => absent,
    notify => Exec['login_systemd_daemon_reload'],
  }

  # Require successful agent discovery; an empty list is valid, a missing or failed fact is not.
  $console_getty_units = $facts['console_gettys']
  if ($console_getty_units =~ Array[String[1]]) {
    # Select the runtime state using the existing effective setting.
    $console_getty_state = $getty_correct ? {
      true    => running,
      false   => stopped,
    }

    # Preserve boot links so stopping a console does not remove it from the next run's selection.
    service { $console_getty_units:
      ensure   => $console_getty_state,
      provider => systemd,
      require  => Exec['login_systemd_daemon_reload'],
    }
  } else {
    fail("Agent console_gettys discovery failed or is missing: ${console_getty_units}")
  }
}
