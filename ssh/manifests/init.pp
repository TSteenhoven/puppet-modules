# @summary Manages hardened OpenSSH server configuration and monitoring.
#
# This class installs OpenSSH packages, replaces `/etc/ssh/sshd_config` with an Include for the module-owned
# `/etc/ssh/sshd_config.d/*.conf`, writes a login banner and custom sshd configuration, supports socket-activated SSH on
# Ubuntu releases that use `ssh.socket`, optionally configures an alternative port, registers a monitoring check, and
# adds audit coverage for SSH configuration changes and SSH client execution.
#
# @example Manage SSH for key-only users
#   class { 'ssh':
#     allow_users => ['deploy', 'admin'],
#   }
#
# @example Use an alternative port for a smaller user set
#   class { 'ssh':
#     allow_users                  => ['admin'],
#     port_alternative             => 2222,
#     port_alternative_allow_users => ['breakglass'],
#   }
#
# @param allow_users
#   Users allowed by the generated sshd configuration. An empty list leaves the template without an explicit AllowUsers
#   list.
#
# @param banner_text
#   Text written to `/etc/issue.net`, `/etc/motd` and referenced by sshd.
#
# @param check_users
#   Optional explicit user list passed to the SSH monitoring check. `undef` derives the list from the primary and
#   alternative allowed users.
#
# @param host_key_algorithms
#   Non-empty list controlling HostKeyAlgorithms, local key generation and explicit HostKey paths.
#   Supports ssh-ed25519, ecdsa-sha2-nistp256/384/521, rsa-sha2-256, rsa-sha2-512 and ssh-rsa; other names
#   are rejected. Defaults to the three ECDSA curves and Ed25519. RSA algorithms share one local RSA key.
#   Existing private keys at the selected paths are retained and missing public keys are derived locally.
#   Keys reside in /etc/ssh/host_keys, a root-owned directory with mode 0700.
#   Each ECDSA curve uses its own ssh_host_ecdsa_nistp<bits>_key file. Unselected key files are left untouched.
#
# @param idle_timeout
#   Idle timeout value rendered into sshd configuration and monitoring.
#
# @param password_authentication_users
#   Users for whom password authentication is allowed by match rules.
#
# @param permit_root_login
#   Controls `PermitRootLogin`. `false` writes `no`, `true` writes `yes`, and a string can set an explicit OpenSSH mode
#   such as `prohibit-password`.
#
# @param port
#   Primary SSH port.
#
# @param port_alternative
#   Optional secondary SSH port, mainly used with socket activation.
#
# @param port_alternative_allow_users
#   Optional AllowUsers list for the alternative port. `undef` reuses `allow_users`.
#
# @api public
class ssh (
  Array                    $allow_users                   = [],
  String                   $banner_text                   = "WARNING: You are entering a managed server!\nThis server should only be accessed by authorized users and must have a valid reason. Disconnect now if you do not comply with these rules.\nAll activity on this system is recorded and forwarded. Unauthorized access will be fully investigated and reported to law enforcement authorities.", # lint:ignore:140chars
  Optional[Array]          $check_users                   = undef,
  Array[String[1], 1]      $host_key_algorithms           = [
    'ecdsa-sha2-nistp256',
    'ecdsa-sha2-nistp384',
    'ecdsa-sha2-nistp521',
    'ssh-ed25519',
  ],
  Integer                  $idle_timeout                  = 300,
  Array                    $password_authentication_users = [],
  Variant[Boolean, String] $permit_root_login             = false,
  Integer                  $port                          = 22,
  Optional[Integer]        $port_alternative              = undef,
  Optional[Array]          $port_alternative_allow_users  = undef,
) {
  # Required packages for SSHD
  package { ['openssh-server', 'openssh-client']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Resolve allowed signature algorithms to local key identities; RSA signatures share the same key.
  $host_key_dir = '/etc/ssh/host_keys'
  $rsa_host_key = { 'path' => "${host_key_dir}/ssh_host_rsa_key", 'type' => 'rsa', 'bits' => 3072 }
  $host_key_mapping = {
    'ecdsa-sha2-nistp256' => { 'path' => "${host_key_dir}/ssh_host_ecdsa_nistp256_key", 'type' => 'ecdsa', 'bits' => 256 },
    'ecdsa-sha2-nistp384' => { 'path' => "${host_key_dir}/ssh_host_ecdsa_nistp384_key", 'type' => 'ecdsa', 'bits' => 384 },
    'ecdsa-sha2-nistp521' => { 'path' => "${host_key_dir}/ssh_host_ecdsa_nistp521_key", 'type' => 'ecdsa', 'bits' => 521 },
    'ssh-ed25519'        => { 'path' => "${host_key_dir}/ssh_host_ed25519_key", 'type' => 'ed25519', 'bits' => 0 },
    'rsa-sha2-256'       => $rsa_host_key,
    'rsa-sha2-512'       => $rsa_host_key,
    'ssh-rsa'            => $rsa_host_key,
  }
  $host_key_settings = $host_key_algorithms.map |$algorithm| {
    assert_type(Hash, $host_key_mapping[$algorithm])
  }.unique
  $host_key_paths = $host_key_settings.map |$settings| { $settings['path'] }

  # Convert array to string
  $allow_users_str = join($allow_users, ' ')
  $password_authentication_users_str = join($password_authentication_users, ',')
  $host_key_algorithms_str = join($host_key_algorithms, ',')

  # Resolve PermitRootLogin to no, yes, or an explicit OpenSSH-supported mode.
  $permit_root_login_correct = $permit_root_login ? {
    true    => 'yes',
    false   => 'no',
    default => $permit_root_login,
  }

  # Check if different list is given for alternative port
  if ($port_alternative_allow_users != undef) {
    # Format the alternate listener's explicit user allowlist for sshd.
    $port_alternative_allow_users_str = join($port_alternative_allow_users, ' ')
  } else {
    # Reuse the primary user allowlist for the alternate SSH listener.
    $port_alternative_allow_users_str = $allow_users_str
  }

  # Get list of users to check
  if ($check_users != undef) {
    # Validate the explicitly selected SSH user list.
    $check_users_complete = $check_users
  } elsif ($port_alternative_allow_users != undef) {
    # Validate users from both primary and alternate SSH allowlists.
    $check_users_complete = flatten($allow_users, $port_alternative_allow_users)
  } else {
    # Validate the primary SSH allowlist when no alternate list is supplied.
    $check_users_complete = $allow_users
  }
  $check_users_str = join($check_users_complete, ',')

  # User filters are inserted into a shell assignment and must remain literal data.
  $check_users_str_shell = stdlib::shell_escape($check_users_str)

  # Check if SSH used socket
  $systemd_enable = defined(Package['systemd'])
  if ($systemd_enable) {
    # Get OS name
    case $facts['os']['name'] {
      'Ubuntu': {
        # Get OS name
        case $facts['os']['release']['major'] {
          '23.04', '24.04': {
            # Use socket activation for the selected Ubuntu release paths.
            $systemd_socket = true
          }
          default: {
            # Use service-based SSH startup on the remaining distribution paths.
            $systemd_socket = false
          }
        }
      }
      default: {
        # Use service-based SSH startup on the remaining distribution paths.
        $systemd_socket = false
      }
    }
  } else {
    # Use service-based SSH startup when systemd is unavailable.
    $systemd_socket = false
  }

  # Check if we have systemd socket and kernel package exists
  if ($systemd_socket and defined(Class['basic_settings::kernel'])) {
    # Get IP versions
    case $basic_settings::kernel::ip_version {
      '4': {
        # Keep the socket's default address binding on an IPv4-only host.
        $ip_version = 'default'
      }
      default: {
        # Allow both IP families on the managed SSH socket.
        $ip_version = 'both'
      }
    }
  } else {
    # Leave address binding at its default without a managed kernel socket policy.
    $ip_version = 'default'
  }

  # Public host-key recovery uses a shell and an external file-presence guard.
  $host_key_packages = ['coreutils', 'dash']
  ensure_packages($host_key_packages, {
    'ensure'          => 'installed',
    'install_options' => ['--no-install-recommends', '--no-install-suggests'],
  })
  $host_key_required_packages = concat($host_key_packages, ['openssh-server'])

  # Restrict access to host identities without purging existing or unselected keys.
  file { $host_key_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Package[$host_key_required_packages],
  }

  # Prepare each selected identity before publishing configuration that references it.
  $host_key_settings.each |$settings| {
    ssh::host_key { $settings['path']:
      bits     => $settings['bits'],
      key_type => $settings['type'],
    }
  }

  # Create SSHD directory config
  file { '/etc/ssh/sshd_config.d':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    force   => true,
    purge   => true,
    recurse => true,
    require => Package['openssh-server'],
  }

  # Banner
  file { ['/etc/issue.net', '/etc/motd']:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "${banner_text}\n\n",
  }

  # Create SSHD custom config
  file { '/etc/ssh/sshd_config.d/99-custom.conf':
    ensure  => file,
    mode    => '0600',
    owner   => 'root',
    group   => 'root',
    content => template('ssh/custom.conf'),
    require => [File['/etc/ssh/sshd_config.d'], Ssh::Host_key[$host_key_paths]],
  }

  # Replace distribution or local settings only after the managed drop-in is available.
  file { '/etc/ssh/sshd_config':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => "# Managed by puppet\nInclude /etc/ssh/sshd_config.d/*.conf\n",
    replace => true,
    require => File['/etc/ssh/sshd_config.d/99-custom.conf'],
  }

  # Subscribe to the same configuration files for socket and service activation.
  $service_configuration_files = [
    '/etc/ssh/sshd_config',
    '/etc/ssh/sshd_config.d',
    '/etc/ssh/sshd_config.d/99-custom.conf',
  ]
  $service_configuration_require = concat(File[$service_configuration_files], Ssh::Host_key[$host_key_paths])

  # Check if we have systemd socket
  if ($systemd_socket) {
    # Reload systemd deamon
    exec { 'ssh_systemd_daemon_reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => Package['systemd'],
    }

    # Socket settings
    if ($port_alternative) {
      # Bind both requested SSH ports with the selected IPv6 socket policy.
      $systemd_socket_settings = {
        'ListenStream' => ['', $port, $port_alternative],
        'BindIPv6Only' => $ip_version,
      }
    } else {
      # Bind the primary SSH port with the selected IPv6 socket policy.
      $systemd_socket_settings = {
        'ListenStream' => ['', $port],
        'BindIPv6Only' => $ip_version,
      }
    }

    # Create drop in for SSH socket
    basic_settings::systemd_drop_in { 'ssh_socket_settings':
      target_unit   => 'ssh.socket',
      socket        => $systemd_socket_settings,
      daemon_reload => 'ssh_systemd_daemon_reload',
      require       => Package['openssh-server'],
    }

    # Disable SSH server service
    service { 'ssh.service':
      ensure    => undef,
      enable    => false,
      require   => File['/etc/ssh/sshd_config.d/99-custom.conf'],
      subscribe => $service_configuration_require,
    }

    # Ensure that ssh is always running
    service { 'ssh.socket':
      ensure  => running,
      enable  => true,
      require => [Package['openssh-server'], File['/etc/ssh/sshd_config']],
    }

    # Set service name
    $service = 'ssh.socket'
  } else {
    # Ensure that ssh is always running
    service { 'ssh':
      ensure    => running,
      enable    => true,
      require   => File['/etc/ssh/sshd_config.d/99-custom.conf'],
      subscribe => $service_configuration_require,
    }

    # Set service name
    $service = 'ssh.service'
  }

  # Create service check
  if (defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none') {
    # Install the check tools, including systemd only for the selected inspection path.
    $monitoring_packages = concat(['mawk', 'procps', 'sed'], $systemd_enable ? {
      true    => ['systemd'],
      default => [],
    })
    ensure_packages($monitoring_packages, {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    })
    $monitoring_required_packages = concat($monitoring_packages, $host_key_packages)

    # Register the check after its runtime packages.
    basic_settings::monitoring_custom { 'ssh':
      content  => template('ssh/check_ssh'),
      friendly => 'SSH',
      timeout  => 60,
      require  => Package[$monitoring_required_packages],
    }
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'ssh':
      rules                    => [
        '-a always,exit -F arch=b32 -F path=/etc/ssh/sshd_config -F perm=r -F auid!=unset -F key=sshd',
        '-a always,exit -F arch=b64 -F path=/etc/ssh/sshd_config -F perm=r -F auid!=unset -F key=sshd',
        '-a always,exit -F arch=b32 -F dir=/etc/ssh/sshd_config.d -F perm=r -F auid!=unset -F key=sshd',
        '-a always,exit -F arch=b64 -F dir=/etc/ssh/sshd_config.d -F perm=r -F auid!=unset -F key=sshd',
        '-a always,exit -F arch=b32 -F path=/etc/ssh/sshd_config -F perm=wa -F key=sshd',
        '-a always,exit -F arch=b64 -F path=/etc/ssh/sshd_config -F perm=wa -F key=sshd',
        '-a always,exit -F arch=b32 -F dir=/etc/ssh/sshd_config.d -F perm=wa -F key=sshd',
        '-a always,exit -F arch=b64 -F dir=/etc/ssh/sshd_config.d -F perm=wa -F key=sshd',
      ],
      rule_suspicious_packages => [
        '/usr/bin/ssh',
      ],
    }
  }
}
