# @summary Manages `/etc/gitlab/gitlab.rb` for an installed GitLab instance.
#
# lint:ignore:140chars
# This class renders the GitLab omnibus configuration and refreshes `gitlab-ctl reconfigure` when it changes. It depends on the main `gitlab` class so it can reuse the resolved server FQDN and installation state.
# lint:endignore
#
# @example Configure GitLab HTTPS and SSH settings
#   class { 'gitlab::config':
#     https               => true,
#     ssh_host            => 'source.example.org',
#     ssh_port            => 2222,
#     ssl_certificate     => '/etc/gitlab/ssl/fullchain.pem',
#     ssl_certificate_key => '/etc/gitlab/ssl/privkey.pem',
#   }
#
# @param database_shared_buffers
#   PostgreSQL shared buffer setting rendered into `gitlab.rb`.
#
# @param https
#   Enables HTTPS-related GitLab configuration. When certificates are omitted, the template enables Let's Encrypt handling.
#
# @param logrotate_rotate
#   Optional logrotate retention count. `undef` inherits `basic_settings::io::log_rotate` when available, otherwise uses 12.
#
# @param puma_max_memory_mb
#   Puma memory limit in megabytes.
#
# @param puma_max_threads
#   Maximum Puma thread count.
#
# @param puma_worker_processes
#   Number of Puma worker processes.
#
# @param sidekiq_concurrency
#   Sidekiq concurrency value rendered into GitLab config.
#
# @param smtp_openssl_verify_mode
#   SMTP OpenSSL verification mode rendered into GitLab config.
#
# @param smtp_server
#   SMTP server. `undef` inherits `basic_settings::smtp_server` or falls back to `127.0.0.1`.
#
# @param ssh_host
#   SSH host advertised by GitLab. `undef` uses the resolved GitLab FQDN.
#
# @param ssh_port
#   SSH port advertised by GitLab.
#
# @param ssl_certificate
#   Optional TLS certificate path rendered into GitLab config.
#
# @param ssl_certificate_key
#   Optional TLS private key path rendered into GitLab config.
#
# @api public
class gitlab::config (
  String               $database_shared_buffers  = '256MB',
  Boolean              $https                    = false,
  Optional[Integer]    $logrotate_rotate         = undef,
  Integer              $puma_max_memory_mb       = 128,
  Integer              $puma_max_threads         = 2,
  Integer              $puma_worker_processes    = 2,
  Integer              $sidekiq_concurrency      = 10,
  Enum['none', 'peer'] $smtp_openssl_verify_mode = 'none',
  Optional[String]     $smtp_server              = undef,
  Optional[String]     $ssh_host                 = undef,
  Integer              $ssh_port                 = 22,
  Optional[String]     $ssl_certificate          = undef,
  Optional[String]     $ssl_certificate_key      = undef,
) {
  # Require the GitLab parent before reading installation settings and rendering configuration.
  if (defined(Class['gitlab'])) {
    # Set variables
    $server_fdqn = $gitlab::server_fdqn_correct

    # Get logrotate rotate
    if ($logrotate_rotate == undef) {
      # Inherit central log retention when available, otherwise use the standalone default.
      if (defined(Class['basic_settings::io'])) {
        # Inherit the central log-retention count.
        $logrotate_rotate_correct = $basic_settings::io::log_rotate
      } else {
        # Keep twelve rotations when no central retention policy is available.
        $logrotate_rotate_correct = 12
      }
    } else {
      # Preserve the caller's log-retention count.
      $logrotate_rotate_correct = $logrotate_rotate
    }

    # Try to get smtp server
    if ($smtp_server == undef) {
      # Use the central SMTP relay when available, otherwise use the local relay.
      if (defined(Class['basic_settings'])) {
        # Inherit the central SMTP relay.
        $smtp_server_correct = $basic_settings::smtp_server
      } else {
        # Fall back to the local SMTP relay without central settings.
        $smtp_server_correct = '127.0.0.1'
      }
    } else {
      # Use the explicitly supplied SMTP relay.
      $smtp_server_correct = $smtp_server
    }

    # Try to get smtp server
    if ($ssh_host == undef) {
      # Advertise the main server FQDN as the default SSH endpoint.
      $ssh_host_correct = $server_fdqn
    } else {
      # Advertise the caller's explicit SSH endpoint.
      $ssh_host_correct = $ssh_host
    }

    # Check if letsencrypt need to be enabled
    if ($https) {
      # Enable automatic certificate management only when HTTPS has no supplied certificate pair.
      if ($ssl_certificate == undef and $ssl_certificate_key == undef) {
        # Let GitLab obtain a certificate when HTTPS has no supplied certificate pair.
        $letsencrypt = true
      } else {
        # Leave certificate issuance disabled when a certificate is already supplied.
        $letsencrypt = false
      }
    } else {
      # Leave certificate issuance disabled for an HTTP-only frontend.
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
  } else {
    fail('Class gitlab is not defined, but is required for gitlab::config')
  }
}
