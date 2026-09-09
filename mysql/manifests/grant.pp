# @summary Grants or revokes MySQL privileges for one user and object scope.
#
# lint:ignore:140chars
# This defined type delegates privilege checks and changes to the module's root-only grant helper script. It escapes all dynamic command arguments before building shell commands and supports MySQL 8 privilege-list compatibility for `ALL PRIVILEGES`.
# lint:endignore
#
# @example Grant privileges on one database
#   mysql::grant { 'app':
#     ensure   => present,
#     username => 'app',
#     database => 'app',
#   }
#
# @param ensure
#   Grants privileges when `present`; revokes them when `absent`.
#
# @param username
#   MySQL username receiving or losing privileges.
#
# @param database
#   Database scope for the privilege. The default is `*`.
#
# @param grant_option
#   Adds the grant option when `true`.
#
# @param hostname
#   MySQL host part for the account. The default is `localhost`.
#
# @param privileges
# lint:ignore:140chars
#   Privilege list to grant or revoke. The list is sorted before comparison so privilege order does not affect idempotency. The default is `['ALL PRIVILEGES']`.
# lint:endignore
#
# @param table
#   Table scope for the privilege. The default is `*`.
#
# @api public
define mysql::grant (
  Enum['present', 'absent'] $ensure,
  String                    $username,
  String                    $database     = '*',
  Boolean                   $grant_option = false,
  String                    $hostname     = 'localhost',
  Array                     $privileges   = ['ALL PRIVILEGES'],
  String                    $table        = '*',
) {
  if (defined(Class['mysql'])) {
    # Set requirements
    Exec {
      require => [Service[$mysql::package_name], File[$mysql::script_path]],
    }

    # Normalize the requested privileges before the grant helper compares them.
    $priv_str = join(sort($privileges), ', ')
    $grant_option_num = $grant_option ? { true => '1', default => '0' }

    # Escape grant wrapper arguments before building exec commands and guards.
    $script_path_shell = stdlib::shell_escape($mysql::script_path)
    $username_shell = stdlib::shell_escape($username)
    $hostname_shell = stdlib::shell_escape($hostname)
    $database_shell = stdlib::shell_escape($database)
    $table_shell = stdlib::shell_escape($table)
    $grant_option_num_shell = stdlib::shell_escape($grant_option_num)

    # Change SQL queries based on version
    if (versioncmp(String($mysql::version), '8.0') >= 0 and $priv_str == 'ALL PRIVILEGES') {
      if ($database != '*') {
        $check_all_priv = $priv_str
      } else {
        $check_all_priv = 'ALTER, ALTER ROUTINE, CREATE, CREATE ROLE, CREATE ROUTINE, CREATE TABLESPACE, CREATE TEMPORARY TABLES, CREATE USER, CREATE VIEW, DELETE, DROP, DROP ROLE, EVENT, EXECUTE, FILE, INDEX, INSERT, LOCK TABLES, PROCESS, REFERENCES, RELOAD, REPLICATION CLIENT, REPLICATION SLAVE, SELECT, SHOW DATABASES, SHOW VIEW, SHUTDOWN, SUPER, TRIGGER, UPDATE' # lint:ignore:140chars
      }

      # Escape version-specific privilege strings before building wrapper arguments.
      $check_all_priv_shell = stdlib::shell_escape($check_all_priv)
      $priv_str_shell = stdlib::shell_escape($priv_str)
      $check_script_args = "${username_shell} ${hostname_shell} ${database_shell} ${table_shell} ${check_all_priv_shell} ${grant_option_num_shell}" # lint:ignore:140chars
      $grant_script_args = "${username_shell} ${hostname_shell} ${database_shell} ${table_shell} ${check_all_priv_shell} ${grant_option_num_shell} ${priv_str_shell}" # lint:ignore:140chars
    } else {
      # Escape the privilege string before building wrapper arguments.
      $priv_str_shell = stdlib::shell_escape($priv_str)
      $check_script_args = "${username_shell} ${hostname_shell} ${database_shell} ${table_shell} ${priv_str_shell} ${grant_option_num_shell}" # lint:ignore:140chars
      $grant_script_args = "${username_shell} ${hostname_shell} ${database_shell} ${table_shell} ${priv_str_shell} ${grant_option_num_shell} ${priv_str_shell}" # lint:ignore:140chars
    }

    # Run query
    case $ensure {
      'present': {
        exec { "mysql_grant_${username}@${hostname}_on_${database}.${table}":
          unless  => "${script_path_shell} check ${check_script_args}",
          command => "${script_path_shell} grant ${grant_script_args}",
        }
      }
      'absent': {
        exec { "mysql_revoke_${username}@${hostname}_on_${database}.${table}":
          onlyif  => "${script_path_shell} check ${check_script_args}",
          command => "${script_path_shell} revoke ${check_script_args}",
        }
      }
      default: {
        fail('Unknown ensure: $ensure, must be present or absent')
      }
    }
  } else {
    fail('Class mysql is not defined, but is required for mysql::grant')
  }
}
