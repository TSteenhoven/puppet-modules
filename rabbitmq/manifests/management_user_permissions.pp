# @summary Manages RabbitMQ permissions for one user and virtual host.
#
# This defined type requires `rabbitmq::management` and applies configure, write, and read permissions with `rabbitmqctl`.
#
# @example Grant read/write access on the default vhost
#   rabbitmq::management_user_permissions { 'app_default':
#     user      => 'app',
#     configure => '',
#     write     => '.*',
#     read      => '.*',
#   }
#
# @param user
#   RabbitMQ user receiving the permissions.
#
# @param configure
#   Configure permission regular expression.
#
# @param read
#   Read permission regular expression.
#
# @param vhost
#   RabbitMQ virtual host where permissions are applied.
#
# @param write
#   Write permission regular expression.
#
# @api public
define rabbitmq::management_user_permissions (
  String $user,
  String $configure = '.*',
  String $read      = '.*',
  String $vhost     = '/',
  String $write     = '.*',
) {
  # Require the management interface before assigning virtual-host permissions.
  if (defined(Class['rabbitmq::management'])) {
    # Get vhost name
    if ($vhost == '/') {
      # Give the root virtual host a readable name in management resource identifiers.
      $vhost_name = 'default'
    } else {
      # Keep the non-root virtual host name in management resource identifiers.
      $vhost_name = $vhost
    }

    # Escape permission arguments before passing them to rabbitmqctl.
    $vhost_shell = stdlib::shell_escape($vhost)
    $user_shell = stdlib::shell_escape($user)
    $configure_shell = stdlib::shell_escape($configure)
    $write_shell = stdlib::shell_escape($write)
    $read_shell = stdlib::shell_escape($read)

    # Compare the tab-separated rabbitmqctl output literally; the permissions
    # themselves are regular expressions and must not be interpreted by grep.
    $permissions_line_shell = stdlib::shell_escape("${vhost}\t${configure}\t${write}\t${read}")

    # Set permissions
    exec { "rabbitmq_management_user_${user}_permissions_${vhost_name}":
      command => "/usr/sbin/rabbitmqctl --quiet set_permissions -p ${vhost_shell} ${user_shell} ${configure_shell} ${write_shell} ${read_shell}", # lint:ignore:140chars
      unless  => "/usr/sbin/rabbitmqctl --quiet list_user_permissions --no-table-headers ${user_shell} | /usr/bin/grep -F -x -- ${permissions_line_shell}", # lint:ignore:140chars
      require => [
        Package['grep'],
        Exec["rabbitmq_management_user_${user}", "rabbitmq_management_vhost_${vhost_name}"],
      ],
    }
  } else {
    fail('The rabbitmq::management class must be included before using the rabbitmq::management_user_permissions defined type.')
  }
}
