define mysql::database (
        Enum['present','absent']    $ensure,
        Optional[String]            $charset = 'utf8',
        Optional[String]            $collate = 'utf8_general_ci',
        Optional[Boolean]           $destroy = false
    ) {

    /* Set requirements */
    Exec {
        require => [Service[$mysql::package_name], File[$mysql::script_path]]
    }

    /* Run query */
    case $ensure {
        present: {
            exec { "mysql_create_database_${title}":
                unless => "/usr/bin/bash -c \"mysql --defaults-file=${mysql::defaults_file} -NBe 'SHOW DATABASES;' | grep -qx '${title}'\"",
                command => "mysql --defaults-file=${mysql::defaults_file} -e \"CREATE DATABASE \\`${title}\\` DEFAULT CHARACTER SET = '${charset}' DEFAULT COLLATE = '${collate}';\"",
            }
        }
        absent: {
            if ($destroy) {
                exec { "mysql_drop_database_${title}":
                    onlyif => "/usr/bin/bash -c \"mysql --defaults-file=${mysql::defaults_file} -NBe 'SHOW DATABASES;' | grep -qx '${title}'\"",
                    command => "mysql --defaults-file=${mysql::defaults_file} -e \"DROP DATABASE \\`${title}\\`;\""
                }
            } else {
                notify { "mysql_drop_database_${title}":
                    message => 'Database is set to absent, but will not be deleted unless $destroy is set to true.'
                }
            }
        }
        default: {
            fail('Unknown ensure: $ensure, must be present or absent')
        }
    }
}
