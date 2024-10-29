class rabbitmq::management (
  Boolean           $admin_enable           = true,
  String              $admin_config_path      = '/etc/rabbitmq/rabbitmqadmin.conf',
  String              $admin_password         = 'guest',
  String              $default_queue_type     = 'classic',
  Integer             $port                   = 15672,
  Optional[String]    $ssl_ca_certificate     = undef,
  Optional[String]    $ssl_certificate        = undef,
  Optional[String]    $ssl_certificate_key    = undef,
  Integer             $ssl_port               = 15671,
  Optional[String]    $ssl_protocols          = undef,
  Optional[String]    $ssl_ciphers            = undef
) {
  # Delete guest user
  exec { 'rabbitmq_management_plugin_guest':
    command     => '/usr/sbin/rabbitmqctl --quiet delete_user guest',
    refreshonly => true,
  }

  # Setup the plugin
  exec { 'rabbitmq_management_plugin':
    command => '/usr/bin/bash -c "(umask 27 && /usr/sbin/rabbitmq-plugins --quiet enable rabbitmq_management)"',
    unless  => '/usr/sbin/rabbitmq-plugins --quiet is_enabled rabbitmq_management',
    notify  => Exec['rabbitmq_management_plugin_guest'],
    require => Package['rabbitmq-server'],
  }

  # Check if all cert variables are given
  if ($ssl_ca_certificate != undef and $ssl_certificate != undef and $ssl_certificate_key != undef) {
    $https_allow = true
    $ssl_ca_certificate_correct = $ssl_ca_certificate
    $ssl_certificate_correct = $ssl_certificate
    $ssl_certificate_key_correct = $ssl_certificate_key
  } elsif (defined(Class['rabbitmq::tcp'])
    and $rabbitmq::tcp::ssl_ca_certificate != undef
    and $rabbitmq::tcp::ssl_certificate != undef
  and $rabbitmq::tcp::ssl_certificate_key != undef) {
    $https_allow = true
    $ssl_ca_certificate_correct = $rabbitmq::tcp::ssl_ca_certificate
    $ssl_certificate_correct = $rabbitmq::tcp::ssl_certificate
    $ssl_certificate_key_correct = $rabbitmq::tcp::ssl_certificate_key
  } else {
    $https_allow = false
    $ssl_ca_certificate_correct = undef
    $ssl_certificate_correct = undef
    $ssl_certificate_key_correct = undef
  }

  # Check if https is active
  if ($https_allow) {
    # Set SSL protocols
    if ($ssl_protocols == undef) {
      if ($rabbitmq::tcp::ssl_protocols == undef) {
        $ssl_protocols_correct = []
      } else {
        $ssl_protocols_correct = $rabbitmq::tcp::ssl_protocols
      }
    } else {
      $ssl_protocols_correct = $ssl_protocols
    }

    # Set SSL ciphers
    if ($ssl_ciphers == undef) {
      if ($rabbitmq::tcp::ssl_ciphers == undef) {
        $ssl_ciphers_correct = []
      } else {
        $ssl_ciphers_correct = $rabbitmq::tcp::ssl_ciphers
      }
    } else {
      $ssl_ciphers_correct = $ssl_ciphers
    }
  } else {
    # Empty SSL ciphers
    $ssl_ciphers_correct = []
  }

  # Create management config file
  file { '/etc/rabbitmq/conf.d/management.conf':
    ensure  => file,
    content => template('rabbitmq/management.conf'),
    owner   => 'rabbitmq',
    group   => 'rabbitmq',
    mode    => '0600',
    notify  => Service['rabbitmq-server'],
    require => File['rabbitmq_config_dir'],
  }

  # Create default vost
  rabbitmq::management_vhost { '/':
    type => $default_queue_type,
  }

  # Check if we need to install admin plugin
  if ($admin_enable) {
    # Enable guest account
    rabbitmq::management_user { 'guest':
      password => $admin_password,
      tags     => ['administrator'],
      Require  => Exec['rabbitmq_management_plugin_guest'],
    }
    rabbitmq::management_user_permissions { 'guest_default':
      user => 'guest',
    }

    # Create admin config file
    file { 'rabbitmq_management_admin_config':
      ensure  => file,
      path    => $admin_config_path,
      content => template('rabbitmq/rabbitmqadmin.conf'),
      owner   => 'rabbitmq',
      group   => 'rabbitmq',
      mode    => '0600',
    }

    # Install admin plugin
    exec { 'rabbitmq_management_admin_cli':
      command => "/usr/bin/curl -fsSL http://127.0.0.1:${port}/cli/rabbitmqadmin -o /usr/sbin/rabbitmqadmin && chmod +x /usr/sbin/rabbitmqadmin",
      unless  => '[ -e /usr/sbin/rabbitmqadmin ]',
      require => [Package['curl'], File['rabbitmq_management_admin_config']],
    }

    # Create list of packages that is suspicious
    $suspicious_packages = ['/usr/sbin/rabbitmqctl', '/usr/sbin/rabbitmqadmin']
  } else {
    # Create list of packages that is suspicious
    $suspicious_packages = ['/usr/sbin/rabbitmqctl']

    # Remove unnecessary files
    file { '/usr/sbin/rabbitmqadmin':
      ensure => absent,
    }
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'rabbitmq_management':
      rule_suspicious_packages => $suspicious_packages,
      rule_options             => ['-F auid!=unset'],
    }
  }
}
