# @summary Manages one PHP-FPM pool configuration.
#
# lint:ignore:140chars
# This defined type requires `php8::fpm` and writes `/etc/php/8.<minor>/fpm/pool.d/<title>.conf`. It resolves the socket path from the parent class defaults unless an explicit `listen` value is supplied.
# lint:endignore
#
# @example Create an application pool
#   php8::fpm_pool { 'app':
#     user  => 'www-data',
#     group => 'www-data',
#   }
#
# @param group
#   Unix group used by the pool worker processes.
#
# @param listen
#   Optional listen socket or address. `undef` uses the module default socket.
#
# @param listen_group
#   Group assigned to the listen socket. Defaults to `group`.
#
# @param listen_mode
#   Mode assigned to the listen socket.
#
# @param user
#   Unix user used by the pool worker processes.
#
# @param listen_user
#   User assigned to the listen socket. Defaults to `user`.
#
# @param pm
#   PHP-FPM process manager mode.
#
# @param pm_max_children
#   Maximum child process count.
#
# @param pm_max_requests
#   Number of requests before a child is recycled. `0` disables recycling.
#
# @param pm_max_spare_servers
#   Maximum spare server count.
#
# @param pm_min_spare_servers
#   Minimum spare server count.
#
# @param pm_procidle_timeout
#   Idle timeout for process manager modes that use it.
#
# @param pm_start_servers
#   Number of child processes started initially.
#
# @api public
define php8::fpm_pool (
  String           $group                = 'www-data',
  Optional[String] $listen               = undef,
  String           $listen_group         = $group,
  String           $listen_mode          = '0660',
  String           $user                 = 'www-data', # Must precede $listen_user; defaults are left-to-right.
  String           $listen_user          = $user,
  String           $pm                   = 'dynamic',
  Integer          $pm_max_children      = 5,
  Integer          $pm_max_requests      = 0,
  Integer          $pm_max_spare_servers = 3,
  Integer          $pm_min_spare_servers = 1,
  String           $pm_procidle_timeout  = '10s',
  Integer          $pm_start_servers     = 2,
) {
  if (defined(Class['php8::fpm'])) {
    # Set variables from parent
    $minor_version = $php8::minor_version
    $skip_default_files = $php8::skip_default_files

    # Set listen path
    if ($listen != undef) {
      $listen_path = $listen
    } elsif ($skip_default_files) {
      $listen_path = "/run/php/php8.${minor_version}-fpm.sock"
    } else {
      $listen_path = '/run/php/php-fpm.sock'
    }

    # Create config file
    file { "/etc/php/8.${minor_version}/fpm/pool.d/${name}.conf":
      ensure  => file,
      content => template('php8/fpm-pool.conf'),
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      notify  => Service["php8.${minor_version}-fpm"],
    }
  } else {
    fail('The php::fpm class must be included before using the php8::fpm_pool defined type.')
  }
}
