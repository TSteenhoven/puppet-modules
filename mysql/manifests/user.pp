
define mysql::user (
        $ensure,
        $username,
        $password = '',
        $hostname = 'localhost',
        $password_latency = 'password'
    ) {

    /* Set requirements */
    Exec {
        require => Service['mysql']
    }

    /* Check if mysql version is 5.7 or 8.0 */
    case $basic_settings::mysql_version {
        '5.7': {
            $password_field = 'authentication_string'
            $password_command = "UPDATE mysql.user SET plugin='mysql_native_password', authentication_string = PASSWORD('${password}'), password_expired = 'N' WHERE User = '${username}' AND Host = '${hostname}';"
            $unless_field = "bash -c \"[ `mysql --defaults-file=${mysql::defaults_file} -NBe \\\"select COUNT(*) from mysql.user where user='${username}' and ${password_field}=PASSWORD('${password}');\\\"` != \\\"0\\\" ]\""
        }
        '8.0': {
            if ($password_latency == 'authentication_string') {
                $password_field = 'authentication_string'
                $password_command = "ALTER USER '${username}'@'${hostname}' IDENTIFIED WITH mysql_native_password BY '${password}';" # use mysql_native_password instead off caching_sha2_password due to old packages non supported
            } else {
                $password_field = 'password'
                $password_command = "ALTER USER '${username}'@'${hostname}' IDENTIFIED BY '${password}';" # use default caching_sha2_password method for saving password 
            }
            $unless_field = "bash -c \"if [ `mysql --defaults-file=${mysql::defaults_file} -NBe 'system mysql -u ${username} --password=\"${password}\" -NBe \\\"SELECT CURRENT_USER()\\\"' > /tmp/mysql.result; cat /tmp/mysql.result;` = '${username}@${hostname}' ]; then exit 0; else exit 1; fi\""
        }
        default: {
            $password_field = 'password'
            $password_command = "SET PASSWORD FOR '${username}'@'${hostname}' = PASSWORD('${password}');"
            $unless_field = "bash -c \"[ `mysql --defaults-file=${mysql::defaults_file} -NBe \\\"select COUNT(*) from mysql.user where user='${username}' and ${password_field}=PASSWORD('${password}');\\\"` != \\\"0\\\" ]\""
        }
    }

    /* Run query */
    case $ensure {
        present: {
            exec { "mysql_create_user_${username}@${hostname}":
                unless => "bash -c \"mysql --defaults-file=${mysql::defaults_file} -NBe 'SELECT user,host from mysql.user;' | grep -qx '${username}\\s${hostname}'\"",
                command => "mysql --defaults-file=${mysql::defaults_file} -e \"CREATE USER '${username}'@'${hostname}';\"",
            }
            ->
            exec { "mysql_set_password_${username}@${hostname}":
                unless => $unless_field,
                command => "mysql --defaults-file=${mysql::defaults_file} -e \"${password_command} FLUSH PRIVILEGES;\"",
            }
        }
        absent: {
            exec { "mysql_drop_user_${username}@${hostname}":
                onlyif => "bash -c \"mysql --defaults-file=${mysql::defaults_file} -NBe 'SELECT user,host from mysql.user;' | grep -qx '${username}\\s${hostname}'\"",
                command => "mysql --defaults-file=${mysql::defaults_file} -e \"DROP USER '${username}'@'${hostname}'; FLUSH PRIVILEGES;\"",
            }
        }
        default: {
            fail('Unknown ensure: $ensure, must be present or absent')
        }
    }
}
