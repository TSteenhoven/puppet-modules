# @summary Creates, updates, or removes a MySQL user account.
#
# lint:ignore:140chars
# This defined type manages a MySQL account through SQL commands using the defaults file prepared by the `mysql` class. It handles MySQL version-specific password syntax and performs credential checks through root-only temporary files for MySQL 8 style authentication.
# lint:endignore
#
# @example Create a MySQL application user
#   mysql::user { 'app':
#     ensure   => present,
#     username => 'app',
#     password => lookup('mysql::app_password'),
#   }
#
# @param ensure
#   Creates or updates the user when `present`; drops it when `absent`.
#
# @param password
# lint:ignore:140chars
#   Password assigned to the MySQL user. This parameter is currently a plain string and should be supplied carefully from trusted profile data.
# lint:endignore
#
# @param username
#   MySQL username to manage.
#
# @param hostname
#   MySQL host part for the account. The default is `localhost`.
#
# @param password_latency
# lint:ignore:140chars
#   Selects the MySQL 8 password storage path. Use `authentication_string` for legacy `mysql_native_password`; the default uses MySQL's default method.
# lint:endignore
#
# @api public
define mysql::user (
  Enum['present', 'absent'] $ensure,
  String                    $password,
  String                    $username,
  String                    $hostname         = 'localhost',
  String                    $password_latency = 'password',
) {
  # Require the MySQL parent before managing database accounts through its service.
  if (defined(Class['mysql'])) {
    # Set requirements
    Exec {
      require => Service['mysql'],
    }

    # Escape MySQL command arguments before using them in exec commands and guards.
    $defaults_file_shell = stdlib::shell_escape($mysql::defaults_file)
    $username_shell = stdlib::shell_escape($username)
    $hostname_shell = stdlib::shell_escape($hostname)
    $user_host_pattern_shell = stdlib::shell_escape("${username}\\s${hostname}")
    $list_users_query_shell = stdlib::shell_escape('SELECT user,host from mysql.user;')

    # Check if mysql version is 5.7, 8.0, 8.4
    case $mysql::version {
      5.7: {
        # Use the MySQL 5.7 authentication column and update syntax.
        $password_field = 'authentication_string'
        $password_command = "UPDATE mysql.user SET plugin='mysql_native_password', authentication_string = PASSWORD('${password}'), password_expired = 'N' WHERE User = '${username}' AND Host = '${hostname}';" # lint:ignore:140chars

        # Escape the password check query and guard script before passing them to bash -c.
        $password_check_query_shell = stdlib::shell_escape("select COUNT(*) from mysql.user where user='${username}' and ${password_field}=PASSWORD('${password}');") # lint:ignore:140chars
        $password_check_script_shell = stdlib::shell_escape("[ \$(/usr/bin/mysql --defaults-file=${defaults_file_shell} -NBe ${password_check_query_shell}) != \"0\" ]") # lint:ignore:140chars
        $unless_field = "/usr/bin/bash -c ${password_check_script_shell}"
      }
      8.0, 8.4: {
        # Select the requested authentication compatibility mode for MySQL 8 accounts.
        if ($password_latency == 'authentication_string') {
          # Use mysql_native_password instead off caching_sha2_password due to old packages non supported
          $password_field = 'authentication_string'
          $password_command = "ALTER USER '${username}'@'${hostname}' IDENTIFIED WITH mysql_native_password BY '${password}';"
        } else {
          # Use default caching_sha2_password method for saving password
          $password_field = 'password'
          $password_command = "ALTER USER '${username}'@'${hostname}' IDENTIFIED BY '${password}';"
        }

        # Verify credentials through a root-only temp dir so the password check leaves no shared /tmp files behind.
        # Escape credential-check values before building the root-only temp config script.
        $password_config_shell = stdlib::shell_escape("[client]\npassword=${password}")
        $current_user_query_shell = stdlib::shell_escape('SELECT CURRENT_USER()')
        $current_user_expected_shell = stdlib::shell_escape("${username}@${hostname}")
        $password_check_script = "umask 077; tmpdir=\$(/usr/bin/mktemp -d /root/mysql-user-check.XXXXXX) || exit 1; trap \"rm -rf \\\"\$tmpdir\\\"\" EXIT; /usr/bin/printf %s ${password_config_shell} > \"\$tmpdir/mysql.cnf\"; current_user=\$(/usr/bin/mysql --defaults-file=\"\$tmpdir/mysql.cnf\" -u ${username_shell} -NBe ${current_user_query_shell} 2>/dev/null); [ \"\$current_user\" = ${current_user_expected_shell} ]" # lint:ignore:140chars

        # Escape the complete credential-check script before passing it to bash -c.
        $password_check_script_shell = stdlib::shell_escape($password_check_script)
        $unless_field = "/usr/bin/bash -c ${password_check_script_shell}"
      }
      default: {
        # Use the legacy password column and SET PASSWORD syntax on the remaining version path.
        $password_field = 'password'
        $password_command = "SET PASSWORD FOR '${username}'@'${hostname}' = PASSWORD('${password}');"

        # Escape the password check query and guard script before passing them to bash -c.
        $password_check_query_shell = stdlib::shell_escape("select COUNT(*) from mysql.user where user='${username}' and ${password_field}=PASSWORD('${password}');") # lint:ignore:140chars
        $password_check_script_shell = stdlib::shell_escape("[ \$(/usr/bin/mysql --defaults-file=${defaults_file_shell} -NBe ${password_check_query_shell}) != \"0\" ]") # lint:ignore:140chars
        $unless_field = "/usr/bin/bash -c ${password_check_script_shell}"
      }
    }

    # Run query
    case $ensure {
      'present': {
        # Escape user-management queries before passing them to mysql -e.
        $create_user_query_shell = stdlib::shell_escape("CREATE USER '${username}'@'${hostname}';")
        $password_command_shell = stdlib::shell_escape("${password_command} FLUSH PRIVILEGES;")

        # Use the shell provider so escaped SQL semicolons, guard pipelines, and bash -c checks stay intact.
        exec { "mysql_create_user_${username}@${hostname}":
          provider => shell,
          unless   => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -NBe ${list_users_query_shell} | /usr/bin/grep -qx ${user_host_pattern_shell}", # lint:ignore:140chars
          command  => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -e ${create_user_query_shell}",
        }
        -> exec { "mysql_set_password_${username}@${hostname}":
          provider => shell,
          unless   => Sensitive.new($unless_field),
          command  => Sensitive.new("/usr/bin/mysql --defaults-file=${defaults_file_shell} -e ${password_command_shell}"),
        }
      }
      'absent': {
        # Escape the DROP USER query before passing it to mysql -e.
        $drop_user_query_shell = stdlib::shell_escape("DROP USER '${username}'@'${hostname}'; FLUSH PRIVILEGES;")

        # Use the shell provider so escaped SQL semicolons and guard pipelines stay intact.
        exec { "mysql_drop_user_${username}@${hostname}":
          provider => shell,
          onlyif   => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -NBe ${list_users_query_shell} | /usr/bin/grep -qx ${user_host_pattern_shell}", # lint:ignore:140chars
          command  => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -e ${drop_user_query_shell}",
        }
      }
      default: {
        fail('Unknown ensure: $ensure, must be present or absent')
      }
    }
  } else {
    fail('Class mysql is not defined, but is required for mysql::user')
  }
}
