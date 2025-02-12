class ssh (
  Array               $allow_users                    = [],
  String              $banner_text                    = "WARNING: You are entering a managed server!\nThis server should only be accessed by authorized users and must have a valid reason. Disconnect now if you do not comply with these rules.\nAll activity on this system is recorded and forwarded. Unauthorized access will be fully investigated and reported to law enforcement authorities.", #lint:ignore:140chars
  Array               $host_key_algorithms            = [
    'ecdsa-sha2-nistp256',
    'ecdsa-sha2-nistp384',
    'ecdsa-sha2-nistp521',
    'ssh-ed25519',
  ],
  Integer             $idle_timeout                   = 15,
  Array               $password_authentication_users  = [],
  Boolean             $permit_root_login              = false,
  Integer             $port                           = 22,
  Optional[Integer]   $port_alternative               = undef,
  Optional[Array]     $port_alternative_allow_users   = undef
) {
  # Required packages for SSHD
  package { ['openssh-server', 'openssh-client']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Convert array to string
  $allow_users_str = join($allow_users, ' ')
  $password_authentication_users_str = join($password_authentication_users, ',')
  $host_key_algorithms_str = join($host_key_algorithms, ',')

  # Check if different list is given for alternative port
  if ($port_alternative_allow_users != undef) {
    $port_alternative_allow_users_str = join($port_alternative_allow_users, ' ')
  } else {
    $port_alternative_allow_users_str = $allow_users_str
  }

  # Check if SSH used socket
  if (defined(Package['systemd'])) {
    # Get OS name
    case $facts['os']['name'] {
      'Ubuntu': {
        # Get OS name
        case $facts['os']['release']['major'] {
          '23.04', '24.04': {
            $systemd_socket = true
          }
          default: {
            $systemd_socket = false
          }
        }
      }
      default: {
        $systemd_socket = false
      }
    }
  } else {
    $systemd_socket = false
  }

  # Check if we have systemd socket and kernel package exists
  if ($systemd_socket and defined(Class['basic_settings::kernel'])) {
    # Get IP versions
    case $basic_settings::kernel::ip_version {
      '4': {
        $ip_version = 'default'
      }
      default: {
        $ip_version = 'both'
      }
    }
  } else {
    $ip_version = 'default'
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
  file { '/etc/issue.net':
    ensure  => file,
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
    require => File['/etc/ssh/sshd_config.d'],
  }

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
      $systemd_socket_settings = {
        'ListenStream' => ['', $port, $port_alternative],
        'BindIPv6Only' => $ip_version,
      }
    } else {
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
      subscribe => [File['/etc/ssh/sshd_config.d'], File['/etc/ssh/sshd_config.d/99-custom.conf']],
    }

    # Ensure that ssh is always running
    service { 'ssh.socket':
      ensure  => running,
      enable  => true,
      require => Package['openssh-server'],
    }
  } else {
    # Ensure that ssh is always running
    service { 'ssh':
      ensure    => running,
      enable    => true,
      require   => File['/etc/ssh/sshd_config.d/99-custom.conf'],
      subscribe => [File['/etc/ssh/sshd_config.d'], File['/etc/ssh/sshd_config.d/99-custom.conf']],
    }
  }

  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'ssh':
      rules                    => [
        '-a always,exit -F arch=b32 -F path=/etc/ssh/sshd_config -F perm=r -F auid!=unset -F key=sshd',
        '-a always,exit -F arch=b64 -F path=/etc/ssh/sshd_config -F perm=r -F auid!=unset -F key=sshd',
        '-a always,exit -F arch=b32 -F path=/etc/ssh/sshd_config.d -F perm=r -F auid!=unset -F key=sshd',
        '-a always,exit -F arch=b64 -F path=/etc/ssh/sshd_config.d -F perm=r -F auid!=unset -F key=sshd',
        '-a always,exit -F arch=b32 -F path=/etc/ssh/sshd_config -F perm=wa -F key=sshd',
        '-a always,exit -F arch=b64 -F path=/etc/ssh/sshd_config -F perm=wa -F key=sshd',
        '-a always,exit -F arch=b32 -F path=/etc/ssh/sshd_config.d -F perm=wa -F key=sshd',
        '-a always,exit -F arch=b64 -F path=/etc/ssh/sshd_config.d -F perm=wa -F key=sshd',
      ],
      rule_suspicious_packages => [
        '/usr/bin/ssh',
      ],
    }
  }
}
