define mysql::grant (
  Enum['present','absent']    $ensure,
  String                      $username,
  String                      $database     = '*',
  Boolean                     $grant_option = false,
  String                      $hostname     = 'localhost',
  Array                       $privileges   = ['ALL PRIVILEGES'],
  String                      $table        = '*'
) {
  # Set requirements
  Exec {
    require => [Service[$mysql::package_name], File[$mysql::script_path]],
  }

  # Set some settings
  $priv_str = join($privileges, ', ')
  $grant_option_num = $grant_option ? { true => '1', default => '0' }

  # Change SQL queries based on version
  if (versioncmp(String($mysql::version), '8.0') >= 0 and $priv_str == 'ALL PRIVILEGES') {
    if ($database != '*') {
      $check_all_priv = $priv_str
    } else {
      $check_all_priv = 'SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, SUPER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER, CREATE TABLESPACE, CREATE ROLE, DROP ROLE'
    }
    $check_script_args = "\"${username}\" \"${hostname}\" \"${database}\" \"${table}\" \"${check_all_priv}\" ${grant_option_num}"
    $grant_script_args = "\"${username}\" \"${hostname}\" \"${database}\" \"${table}\" \"${check_all_priv}\" ${grant_option_num} \"${priv_str}\""
  } else {
    $check_script_args = "\"${username}\" \"${hostname}\" \"${database}\" \"${table}\" \"${priv_str}\" ${grant_option_num}"
    $grant_script_args = "\"${username}\" \"${hostname}\" \"${database}\" \"${table}\" \"${priv_str}\" ${grant_option_num} \"${priv_str}\""
  }

  # Run query
  case $ensure {
    'present': {
      exec { "mysql_grant_${username}@${hostname}_on_${database}.${table}":
        unless  => "${mysql::script_path} check ${check_script_args}",
        command => "${mysql::script_path} grant ${grant_script_args}",
      }
    }
    'absent': {
      exec { "mysql_revoke_${username}@${hostname}_on_${database}.${table}":
        onlyif  => "${mysql::script_path} check ${check_script_args}",
        command => "${mysql::script_path} revoke ${check_script_args}",
      }
    }
    default: {
      fail('Unknown ensure: $ensure, must be present or absent')
    }
  }
}
