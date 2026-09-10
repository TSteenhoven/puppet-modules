# @summary Creates or optionally drops a MySQL database.
#
# lint:ignore:140chars
# This defined type uses the MySQL defaults file prepared by the `mysql` class to create a database with the requested charset and collation, optionally import a SQL file after creation, or drop the database only when explicit destruction is allowed.
# lint:endignore
#
# @example Create a UTF-8 database
#   mysql::database { 'app':
#     ensure => present,
#   }
#
# @param ensure
#   Creates the database when `present`; handles removal behavior when `absent`.
#
# @param charset
#   Default character set used in the `CREATE DATABASE` statement.
#
# @param collate
#   Default collation used in the `CREATE DATABASE` statement.
#
# @param destroy
#   Allows the database to be dropped when `ensure` is `absent`. The default is `false` to avoid accidental data loss.
#
# @param import
#   Optional SQL file path imported after database creation.
#
# @api public
define mysql::database (
  Enum['present', 'absent'] $ensure,
  String                    $charset = 'utf8',
  String                    $collate = 'utf8_general_ci',
  Boolean                   $destroy = false,
  Optional[String]          $import  = undef,
) {
  # Require the MySQL parent before managing databases through its service and helper.
  if (defined(Class['mysql'])) {
    # Set requirements
    Exec {
      require => [Service[$mysql::package_name], File[$mysql::script_path]],
    }

    # Escape MySQL command arguments before using them in exec commands and guards.
    $defaults_file_shell = stdlib::shell_escape($mysql::defaults_file)
    $database_shell = stdlib::shell_escape($title)
    $show_databases_query_shell = stdlib::shell_escape('SHOW DATABASES;')

    # Run query
    case $ensure {
      'present': {
        # Check if we need import SQL to database
        if ($import != undef) {
          # Escape the import path before using it as a shell redirection source.
          $import_shell = stdlib::shell_escape($import)

          # Import database from file
          exec { "mysql_database_import_${title}":
            command     => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -D ${database_shell} < ${import_shell}",
            refreshonly => true,
          }
          $notify = Exec["mysql_database_import_${title}"]
        } else {
          # Avoid an import notification when no database import is configured.
          $notify = undef
        }

        # Escape the CREATE DATABASE query before passing it to mysql -e.
        $create_database_query_shell = stdlib::shell_escape("CREATE DATABASE `${title}` DEFAULT CHARACTER SET = '${charset}' DEFAULT COLLATE = '${collate}';") # lint:ignore:140chars

        # Create database through the shell provider so escaped SQL semicolons and guard pipelines stay intact.
        exec { "mysql_create_database_${title}":
          provider => shell,
          unless   => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -NBe ${show_databases_query_shell} | /usr/bin/grep -qx ${database_shell}", # lint:ignore:140chars
          command  => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -e ${create_database_query_shell}",
          notify   => $notify,
        }
      }
      'absent': {
        # Drop the database only when destructive removal is explicitly enabled.
        if ($destroy) {
          # Escape the DROP DATABASE query before passing it to mysql -e.
          $drop_database_query_shell = stdlib::shell_escape("DROP DATABASE `${title}`;")

          # Drop database through the shell provider so escaped SQL semicolons and guard pipelines stay intact.
          exec { "mysql_drop_database_${title}":
            provider => shell,
            onlyif   => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -NBe ${show_databases_query_shell} | /usr/bin/grep -qx ${database_shell}", # lint:ignore:140chars
            command  => "/usr/bin/mysql --defaults-file=${defaults_file_shell} -e ${drop_database_query_shell}",
          }
        } else {
          notify { "mysql_drop_database_${title}":
            message => 'Database is set to absent, but will not be deleted unless $destroy is set to true.',
          }
        }
      }
      default: {
        fail('Unknown ensure: $ensure, must be present or absent')
      }
    }
  } else {
    fail('Class mysql is not defined, but is required for mysql::database')
  }
}
