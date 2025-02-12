define rabbitmq::management_user (
  Enum['present','absent']    $ensure     = present,
  Optional[String]            $password   = undef,
  Array                       $tags       = ['monitoring']
) {
  # Set commands
  $find = "/usr/sbin/rabbitmqctl --quiet list_user_limits --user ${name}"

  case $ensure {
    'present': {
      # When password is not given; Create random passowrd
      if ($password == undef) {
        if (defined(Resource['basic_settings::login_user', $name])) {
          # Set defualt values
          $user_home = getparam(Resource['basic_settings::login_user', $name], 'home')
          $user_require = [Package['pwgen'], Exec['rabbitmq_management_plugin']]

          # Important, don't use --quiet here
          $user_addd = "/usr/bin/bash -c 'TMPPASS=`/usr/bin/pwgen -s 26 1`; echo \$TMPPASS > ${user_home}/.rabbitmq.password; /usr/bin/chown ${name}:${name} ${user_home}/.rabbitmq.password; /usr/bin/chmod 600 ${user_home}/.rabbitmq.password; echo \$TMPPASS | /usr/sbin/rabbitmqctl add_user ${name}'" #lint:ignore:140chars
        } else {
          fail("User ${name} not present")
        }
      } else {
        $user_addd = "/usr/sbin/rabbitmqctl add_user ${name} ${password}" # Important, don't use --quiet here
        $user_require = Exec['rabbitmq_management_plugin']
      }

      # Create user
      exec { "rabbitmq_management_user_${name}":
        command => $user_addd,
        unless  => $find,
        require => $user_require,
      }

      # Set tags
      if ($tags != undef) {
        $user_tags_join = join($tags, ' ')
        $user_tags_search = join($tags, ' | grep ')
        exec { "rabbitmq_management_user_${name}_tags":
          command => "/usr/sbin/rabbitmqctl --quiet set_user_tags ${name} ${user_tags_join}",
          unless  => "/usr/sbin/rabbitmqctl --quiet list_users --no-table-headers | /usr/bin/grep ${name} | /usr/bin/cut -f2 | /usr/bin/grep ${user_tags_search}", #lint:ignore:140chars
          require => [Package['coreutils'], Package['grep'], Exec["rabbitmq_management_user_${name}"]],
        }
      }
    }
    'absent': {
      # Delete user
      exec { "rabbitmq_management_user_${name}":
        onlyif  => $find,
        command => "/usr/sbin/rabbitmqctl --quiet delete_user ${name}",
      }
    }
    default: {
      fail('Unknown ensure: $ensure, must be present or absent')
    }
  }
}
