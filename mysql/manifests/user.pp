define mysql::user (
  Enum['present','absent']    $ensure,
  String                      $username,
  String                      $password,
  String                      $password_latency   = 'password',
  String                      $hostname           = 'localhost'
) {
  # Set requirements
  Exec {
    require => Service['mysql'],
  }

  # Check if mysql version is 5.7, 8.0, 8.4
  case $mysql::version {
    5.7: {
      $password_field = 'authentication_string'
      $password_command = "UPDATE mysql.user SET plugin='mysql_native_password', authentication_string = PASSWORD('${password}'), password_expired = 'N' WHERE User = '${username}' AND Host = '${hostname}';" #lint:ignore:140chars
      $unless_field = "/usr/bin/bash -c \"[ `mysql --defaults-file=${mysql::defaults_file} -NBe \\\"select COUNT(*) from mysql.user where user='${username}' and ${password_field}=PASSWORD('${password}');\\\"` != \\\"0\\\" ]\"" #lint:ignore:140chars
    }
    8.0, 8.4: {
      if ($password_latency == 'authentication_string') {
        # Use mysql_native_password instead off caching_sha2_password due to old packages non supported
        $password_field = 'authentication_string'
        $password_command = "ALTER USER '${username}'@'${hostname}' IDENTIFIED WITH mysql_native_password BY '${password}';"
      } else {
        # Use default caching_sha2_password method for saving password
        $password_field = 'password'
        $password_command = "ALTER USER '${username}'@'${hostname}' IDENTIFIED BY '${password}';"
      }
      $unless_field = "/usr/bin/bash -c \"if [ `touch /tmp/mysql.cnf && chmod 600 /tmp/mysql.cnf && printf '%b' '[client]\\npassword=${password}' > /tmp/mysql.cnf; mysql --defaults-file=${mysql::defaults_file} -NBe 'system mysql --defaults-file=/tmp/mysql.cnf -u ${username} -NBe \\\"SELECT CURRENT_USER()\\\"' > /tmp/mysql.result; rm /tmp/mysql.cnf; cat /tmp/mysql.result;` = '${username}@${hostname}' ]; then exit 0; else exit 1; fi\"" #lint:ignore:140chars
    }
    default: {
      $password_field = 'password'
      $password_command = "SET PASSWORD FOR '${username}'@'${hostname}' = PASSWORD('${password}');"
      $unless_field = "/usr/bin/bash -c \"[ `mysql --defaults-file=${mysql::defaults_file} -NBe \\\"select COUNT(*) from mysql.user where user='${username}' and ${password_field}=PASSWORD('${password}');\\\"` != \\\"0\\\" ]\"" #lint:ignore:140chars
    }
  }

  # Run query
  case $ensure {
    'present': {
      exec { "mysql_create_user_${username}@${hostname}":
        unless  => "/usr/bin/bash -c \"mysql --defaults-file=${mysql::defaults_file} -NBe 'SELECT user,host from mysql.user;' | grep -qx '${username}\\s${hostname}'\"",
        command => "mysql --defaults-file=${mysql::defaults_file} -e \"CREATE USER '${username}'@'${hostname}';\"",
      }
      -> exec { "mysql_set_password_${username}@${hostname}":
        unless  => Sensitive.new($unless_field),
        command => Sensitive.new("mysql --defaults-file=${mysql::defaults_file} -e \"${password_command} FLUSH PRIVILEGES;\""),
      }
    }
    'absent': {
      exec { "mysql_drop_user_${username}@${hostname}":
        onlyif  => "/usr/bin/bash -c \"mysql --defaults-file=${mysql::defaults_file} -NBe 'SELECT user,host from mysql.user;' | grep -qx '${username}\\s${hostname}'\"",
        command => "mysql --defaults-file=${mysql::defaults_file} -e \"DROP USER '${username}'@'${hostname}'; FLUSH PRIVILEGES;\"",
      }
    }
    default: {
      fail('Unknown ensure: $ensure, must be present or absent')
    }
  }
}
