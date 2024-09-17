class gitlab::config (
  String                $database_shared_buffers    = '256MB',
  Boolean               $https                      = false,
  Optional[Integer]     $logrotate_rotate           = undef,
  Integer               $puma_worker_processes      = 0,
  Integer               $sidekiq_concurrency        = 10,
  Optional[String]      $ssh_host                   = undef,
  Integer               $ssh_port                   = 22,
  Optional[String]      $ssl_certificate            = undef,
  Optional[String]      $ssl_certificate_key        = undef,
  Optional[String]      $smtp_server                = undef,
  Enum['none', 'peer']  $smtp_openssl_verify_mode   = 'none'
) {
  # Set variables
  $server_fdqn = $gitlab::server_fdqn_correct

  # Get logrotate rotate
  if ($logrotate_rotate == undef) {
    if (defined(Class['basic_settings::io'])) {
      $logrotate_rotate_correct = $basic_settings::io::log_rotate
    } else {
      $logrotate_rotate_correct = 12
    }
  } else {
    $logrotate_rotate_correct = $logrotate_rotate
  }

  # Try to get smtp server
  if ($smtp_server == undef) {
    if (defined(Class['basic_settings'])) {
      $smtp_enable = true
      $smtp_server_correct = $basic_settings::smtp_server
    } else {
      $smtp_enable = false
      $smtp_server_correct = undef
    }
  } else {
    $smtp_enable = true
    $smtp_server_correct = $smtp_server
  }

  # Try to get smtp server
  if ($ssh_host == undef) {
    $ssh_host_correct = $server_fdqn
  } else {
    $ssh_host_correct = $ssh_host
  }

  # Check if letsencrypt need to be enabled
  if ($https) {
    if ($ssl_certificate == undef and $ssl_certificate_key == undef) {
      $letsencrypt = true
    } else {
      $letsencrypt = false
    }
  } else {
    $letsencrypt = false
  }

  # Reload source list
  exec { 'gitlab_config_reconfigure':
    command     => '/usr/bin/gitlab-ctl reconfigure',
    timeout     => 0,
    refreshonly => true,
  }

  # Gitlab config
  file { '/etc/gitlab/gitlab.rb':
    ensure  => file,
    content => template('gitlab/gitlab.rb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Exec['gitlab_config_reconfigure'],
  }
}
