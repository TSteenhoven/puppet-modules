# @summary Installs GitLab EE and integrates it with local systemd, monitoring, and audit policy.
#
# This class installs GitLab EE with the provided initial root credentials, optionally relocates `/opt/gitlab`, manages
# the SSL directory, disables vendor service enablement when systemd integration is available, binds GitLab into the
# shared target ladder, adds monitoring, and installs audit exclusions for known GitLab runtime behavior. The root
# password is used during installation and is passed to the install command as sensitive content.
#
# @example Install GitLab with an explicit FQDN
#   class { 'gitlab':
#     root_password => lookup('gitlab::root_password'),
#     server_fdqn   => 'gitlab.example.org',
#   }
#
# @param root_password
#   Initial GitLab root password used by the package install command.
#
# @param install_dir
#   Optional replacement target for `/opt/gitlab`. When set, the class creates the directory and symlinks `/opt/gitlab`
#   to it.
#
# @param nice_level
#   Positive nice value converted to a negative service priority in the systemd drop-in. The default is 12.
#
# @param root_email
#   Initial GitLab root email. `undef` inherits monitoring mail when available, otherwise uses `root@<server_fdqn>`.
#
# @param server_fdqn
#   External GitLab FQDN used for `EXTERNAL_URL`. `undef` inherits `basic_settings::server_fdqn` or the Facter FQDN.
#
# @api public
class gitlab (
  String           $root_password,
  Optional[String] $install_dir   = undef,
  Integer          $nice_level    = 12,
  Optional[String] $root_email    = undef,
  Optional[String] $server_fdqn   = undef,
) {
  # Set some values
  $suspicious_packages = ['/usr/bin/gitlab-ctl']
  $monitoring_enable = defined(Class['basic_settings::monitoring'])
  $basic_settings_enable = defined(Class['basic_settings'])

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

  # Try to get root email
  if ($root_email == undef) {
    # Use the monitoring contact for the initial administrator when monitoring is configured.
    if ($monitoring_enable) {
      # Reuse the monitoring notification address for the initial administrator contact.
      $root_email_found = $basic_settings::monitoring::mail_to
    } else {
      # Use root as the default administrator contact before adding the server domain.
      $root_email_found = 'root'
    }
  } else {
    # Preserve the caller's administrator contact.
    $root_email_found = $root_email
  }

  # Set email
  if ($root_email_found == 'root') {
    # Qualify the default root address with the selected server FQDN.
    $root_email_correct = "root@${server_fdqn_correct}"
  } else {
    # Keep an explicitly selected administrator address unchanged.
    $root_email_correct = $root_email_found
  }

  # Check if installation dir is given
  if ($install_dir != undef) {
    # Create ssl directory
    $install_dir_correct = $install_dir
    file { 'gitlab_install_dir':
      ensure => directory,
      path   => $install_dir,
      owner  => 'root',
      group  => 'root',
      mode   => '0755', # Important for internal scripts
    }

    # Create symlink
    file { '/opt/gitlab':
      ensure  => 'link',
      owner   => 'root',
      group   => 'root',
      target  => $install_dir,
      force   => true,
      require => File['gitlab_install_dir'],
    }

    # Set requirements
    $requirements = [File['/opt/gitlab'], Package['dpkg', 'grep']]
  } else {
    # Set requirements
    $install_dir_correct = '/opt/gitlab'
    $requirements = [Package['dpkg', 'grep']]
  }

  # Escape install environment values before they are embedded in the shell command.
  $root_email_correct_shell = stdlib::shell_escape($root_email_correct)
  $root_password_shell = stdlib::shell_escape($root_password)
  $external_url_shell = stdlib::shell_escape("http://${server_fdqn_correct}")
  $gitlab_install_script = "GITLAB_ROOT_EMAIL=${root_email_correct_shell} GITLAB_ROOT_PASSWORD=${root_password_shell} EXTERNAL_URL=${external_url_shell} /usr/bin/apt-get install gitlab-ee" # lint:ignore:140chars

  # Escape the complete install script before passing it to sh -c.
  $gitlab_install_script_shell = stdlib::shell_escape($gitlab_install_script)

  # Check if gitlab is installed exists
  exec { 'gitlab_install':
    command => Sensitive.new("/bin/sh -c ${gitlab_install_script_shell}"),
    unless  => '/usr/bin/dpkg -l | /usr/bin/grep gitlab-ee',
    timeout => 0,
    require => $requirements,
  }

  # Create ssl directory
  file { 'gitlab_ssl':
    ensure  => directory,
    path    => '/etc/gitlab/ssl',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Exec['gitlab_install'],
  }

  # Register the GitLab unit reload only when the systemd package dependency exists.
  if (defined(Package['systemd'])) {
    # Reload systemd deamon
    exec { 'gitlab_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Check if basic settings is defined
    if ($basic_settings_enable) {
      # Disable Gitlab service
      service { 'gitlab-runsvdir':
        ensure  => undef,
        enable  => false,
        require => Exec['gitlab_install'],
      }

      # Create drop in for services target
      basic_settings::systemd_drop_in { 'gitlab_dependency':
        target_unit   => "${basic_settings::cluster_id}-services.target",
        unit          => {
          'BindsTo'   => 'gitlab-runsvdir.service',
        },
        daemon_reload => 'gitlab_systemd_daemon_reload',
        require       => Basic_settings::Systemd_target["${basic_settings::cluster_id}-services"],
      }
    }

    # Get unit
    if ($monitoring_enable) {
      # Route unit failures through the configured monitoring notification service.
      $unit = {
        'OnFailure' => 'notify-failed@%i.service',
      }
    } else {
      # Leave unit failure hooks empty when monitoring is unavailable.
      $unit = {}
    }

    # Create drop in for nginx service
    basic_settings::systemd_drop_in { 'gitlab_settings':
      target_unit   => 'gitlab-runsvdir.service',
      unit          => $unit,
      service       => {
        'Nice'          => "-${nice_level}",
      },
      daemon_reload => 'gitlab_systemd_daemon_reload',
      require       => Exec['gitlab_install'],
    }
  }

  # Create service check
  if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
    basic_settings::monitoring_custom { 'gitlab':
      source   => 'puppet:///modules/gitlab/check_gitlab',
      friendly => 'GitLab',
      timeout  => 300,
      interval => 600,
    }
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'gitlab_exclude':
      rules   => [
        # GitLab's bundled Prometheus periodically probes TSDB metadata; interrupted reads in that data directory are expected.
        '-a never,exit -F arch=b32 -S open,openat,open_by_handle_at -F dir=/var/opt/gitlab/prometheus/data -F exe=/usr/local/lib/gitlab/embedded/bin/prometheus -F gid=gitlab-prometheus -F success=0', # lint:ignore:140chars
        '-a never,exit -F arch=b64 -S openat,openat2,open_by_handle_at -F dir=/var/opt/gitlab/prometheus/data -F exe=/usr/local/lib/gitlab/embedded/bin/prometheus -F gid=gitlab-prometheus -F success=0', # lint:ignore:140chars

        # User-systemd setup for the GitLab account creates runtime markers, transient xattrs, and mount probes.
        '-a never,exit -F arch=b32 -S mknodat,mount,umount2,chmod,fchmod,fchmodat,chown,fchown,fchownat,setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F exe=/usr/lib/systemd/systemd -F auid=git -F uid=git -F gid=git', # lint:ignore:140chars
        '-a never,exit -F arch=b64 -S mknodat,mount,umount2,fchmod,fchmodat,fchown,fchownat,setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F exe=/usr/lib/systemd/systemd -F auid=git -F uid=git -F gid=git', # lint:ignore:140chars

        # GitLab SSH sessions call systemctl for user-manager state checks; systemd-owned configuration writes remain audited.
        '-a never,exit -F arch=b32 -F exe=/usr/bin/systemctl -F auid=git',
        '-a never,exit -F arch=b64 -F exe=/usr/bin/systemctl -F auid=git',

        # PAM and update-motd run a root-owned command chain inside Git SSH sessions; auditd cannot scope this to the shared account's argv.
        '-a never,exit -F arch=b32 -S execve -F auid=git -F uid=root -F euid=root -F gid=root',
        '-a never,exit -F arch=b64 -S execve -F auid=git -F uid=root -F euid=root -F gid=root',

        # Prometheus reads kernel time-discipline state for its own metrics, which otherwise trips the baseline time-change audit rule.
        '-a never,exit -F arch=b32 -S adjtimex -F gid=gitlab-prometheus',
        '-a never,exit -F arch=b64 -S adjtimex -F gid=gitlab-prometheus',

        # GitLab's bundled Ruby adjusts GitLab-managed runtime files during daemon housekeeping before any login audit session exists.
        '-a never,exit -F arch=b32 -S chmod -F exe=/usr/local/lib/gitlab/embedded/bin/ruby -F auid=unset',
        '-a never,exit -F arch=b64 -S chmod -F exe=/usr/local/lib/gitlab/embedded/bin/ruby -F auid=unset',

        # GitLab's bundled Ruby opens repository data as the git group; keep this scoped to that executable and group.
        '-a never,exit -F arch=b32 -S open,openat,open_by_handle_at -F exe=/usr/local/lib/gitlab/embedded/bin/ruby -F gid=git',
        '-a never,exit -F arch=b64 -S openat,openat2,open_by_handle_at -F exe=/usr/local/lib/gitlab/embedded/bin/ruby -F gid=git',
      ],
      order   => 2,
      require => Exec['gitlab_install'],
    }

    # Keep suspicious package execution audited alongside the scoped runtime exclusions.
    basic_settings::security_audit { 'gitlab_packages':
      rule_suspicious_packages => $suspicious_packages,
      require                  => Exec['gitlab_install'],
    }
  }
}
