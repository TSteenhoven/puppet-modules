define rabbitmq::management_user_permissions (
  String $user,
  String $vhost       = '/',
  String $configure   = '.*',
  String $write       = '.*',
  String $read        = '.*'
) {
  # Get vhost name
  if ($vhost == '/') {
    $vhost_name = 'default'
  } else {
    $vhost_name = $vhost
  }

  # Set permissions
  exec { "rabbitmq_management_user_${user}_permissions_${vhost_name}":
    command => "/usr/sbin/rabbitmqctl --quiet set_permissions -p ${vhost} ${user} '${configure}' '${write}' '${read}'",
    unless  => "/usr/sbin/rabbitmqctl --quiet list_user_permissions --no-table-headers ${user} | /usr/bin/tr -d '\t' | /usr/bin/grep '${vhost}${configure}${write}${read}'", #lint:ignore:140chars
    require => [
      Package['coreutils'],
      Package['grep'],
      Exec["rabbitmq_management_vhost_${vhost_name}"],
      Exec["rabbitmq_management_user_${user}"]
    ],
  }
}
