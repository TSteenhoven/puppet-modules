# @summary Manages the MySQL upstream APT repository, key, and pinning policy.
#
# lint:ignore:140chars
# This private helper writes or removes the MySQL package source, repository key, and APT preference file. It supports MySQL version-specific key selection and is called by `basic_settings` after OS support has been calculated.
# lint:endignore
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_mysql':
#     deb_version => 'list',
#     enable      => true,
#     os_name     => 'bookworm',
#     os_parent   => 'debian',
#     version     => 8.4,
#   }
#
# @param deb_version
#   APT source format to manage: `list` or `822`.
#
# @param enable
#   Creates the repository, key, and preference file when `true`; removes them when `false`.
#
# @param os_name
#   Distribution codename used in the repository suite.
#
# @param os_parent
#   Distribution family used in the repository URL.
#
# @param version
#   MySQL version used in repository component and key selection. The default is 8.0.
#
# @api private
class basic_settings::package_mysql (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
  Float               $version     = 8.0,
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    # Use the .sources filename for a deb822 repository definition.
    $source_file = '/etc/apt/sources.list.d/mysql.sources'
  } else {
    # Use the .list filename for a one-line APT repository definition.
    $source_file = '/etc/apt/sources.list.d/mysql.list'
  }
  $file_preference = '/etc/apt/preferences.d/90-mysql'

  # Set keyrings file
  $key_file = '/usr/share/keyrings/mysql.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $source_file_shell = stdlib::shell_escape($source_file)
  $file_preference_shell = stdlib::shell_escape($file_preference)
  $key_file_shell = stdlib::shell_escape($key_file)
  $key_rebuild = "cat /usr/share/keyrings/mysql.key | gpg --dearmor | tee ${key_file_shell} >/dev/null; chmod 644 ${key_file_shell}; /usr/bin/apt-get update" # lint:ignore:140chars

  # Install the MySQL repository when enabled and remove its managed source otherwise.
  if ($enable) {
    # Get source name
    case $version {
      8.0: {
        # Pair the MySQL 8 signing key with the 8.0 repository component.
        $key_filename = 'mysql-8.key'
        $version_correct = $version
      }
      8.4: {
        # Pair the MySQL 8 signing key with the LTS repository component.
        $key_filename = 'mysql-8.key'
        $version_correct = "${version}-lts"
      }
      default: {
        # Use the older signing-key mapping for the remaining MySQL versions.
        $key_filename = 'mysql-7.key'
        $version_correct = $version
      }
    }

    # Get source
    if ($deb_version == '822') {
      # Render the selected repository and signing key in deb822 format.
      $source_content  = "Types: deb\\nURIs: https://repo.mysql.com/apt/${os_parent}\\nSuites: ${os_name}\\nComponents: mysql-${version_correct}\\nSigned-By:${key_file}\\n" # lint:ignore:140chars
    } else {
      # Render the selected repository and signing key in one-line APT format.
      $source_content = "deb [signed-by=${key_file}] https://repo.mysql.com/apt/${os_parent} ${os_name} mysql-${version_correct}\\n"
    }

    # Escape generated repo and preference content as literal newline sequences before the shell writes it.
    $source_content_shell = stdlib::shell_escape("# Managed by puppet\\n${source_content}")
    $preference_content_shell = stdlib::shell_escape("# Managed by puppet\\nPackage: mysql*\\nPin: origin repo.mysql.com\\nPin-Priority: 990\\n") # lint:ignore:140chars

    # Rebuild key
    exec { 'package_mysql_key_build':
      command     => $key_rebuild,
      onlyif      => "/usr/bin/test -e ${key_file_shell}",
      refreshonly => true,
      require     => Package['apt', 'apt-transport-https', 'gnupg'],
    }

    # Create MySQL key
    file { 'package_mysql_key_filename':
      ensure => file,
      path   => '/usr/share/keyrings/mysql.key',
      source => "puppet:///modules/basic_settings/mysql/${key_filename}",
      owner  => 'root',
      group  => 'root',
      mode   => '0600',
      notify => Exec['package_mysql_key_build'],
    }

    # Set source
    exec { 'package_mysql_source':
      command => "/usr/bin/printf %b ${source_content_shell} > ${source_file_shell}; ${key_rebuild}",
      unless  => "/usr/bin/test -e ${source_file_shell}",
      require => [Package['apt', 'apt-transport-https', 'gnupg'], File['package_mysql_key_filename']],
    }

    # Set preference
    exec { 'package_mysql_preference':
      command => "/usr/bin/printf %b ${preference_content_shell} > ${file_preference_shell}; chmod 644 ${file_preference_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_preference_shell}",
      require => Exec['package_mysql_source'],
    }
  } else {
    # Remove mysql repo
    exec { 'package_mysql_source':
      command => "/usr/bin/rm ${source_file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${source_file_shell}",
      require => Package['apt'],
    }

    # Remove mysql preference
    exec { 'package_mysql_preference':
      command => "/usr/bin/rm ${file_preference_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_preference_shell}",
      require => Package['apt'],
    }

    # Remove MySQL key
    file { 'package_mysql_key_filename':
      ensure => absent,
      path   => '/usr/share/keyrings/mysql.key',
    }

    # Remove the active repository key as well as the obsolete key filename.
    file { 'package_mysql_key':
      ensure => absent,
      path   => $key_file,
    }
  }
}
