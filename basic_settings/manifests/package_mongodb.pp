# @summary Manages the MongoDB upstream APT repository and server package.
#
# This private helper writes or removes the MongoDB package source and signing key, and installs or purges
# `mongodb-org-server` with the repository state. It is called by `basic_settings` after OS support has been calculated.
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_mongodb':
#     deb_version => 'list',
#     enable      => true,
#     os_name     => 'bookworm',
#     os_parent   => 'debian',
#     version     => 8.0,
#   }
#
# @param deb_version
#   APT source format to manage: `list` or `822`.
#
# @param enable
#   Creates the repository, imports its key, and installs the server package when `true`; removes them when `false`.
#
# @param os_name
#   Distribution codename used in the repository suite.
#
# @param os_parent
#   Distribution family used in the repository URL.
#
# @param version
#   MongoDB major version used in the repository path. The default is 8.0.
#
# @api private
class basic_settings::package_mongodb (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
  Float               $version     = 8.0,
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    # Use the .sources filename for a deb822 repository definition.
    $file = '/etc/apt/sources.list.d/mongodb.sources'
  } else {
    # Use the .list filename for a one-line APT repository definition.
    $file = '/etc/apt/sources.list.d/mongodb.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/mongodb.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  # Install the MongoDB repository when enabled and remove its managed source otherwise.
  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      # Render the selected repository and signing key in deb822 format.
      $source  = "Types: deb\\nURIs: https://repo.mongodb.org/apt/${os_parent}\\nSuites: ${os_name}/mongodb-org/${version}\\nComponents: main\\nSigned-By:${key}\\n" # lint:ignore:140chars
    } else {
      # Render the selected repository and signing key in one-line APT format.
      $source = "deb [signed-by=${key}] https://repo.mongodb.org/apt/${os_parent} ${os_name}/mongodb-org/${version} main\\n"
    }

    # Escape generated repo content as literal newline sequences and key URL before the shell writes or fetches them.
    $source_shell = stdlib::shell_escape("# Managed by puppet\\n${source}")
    $key_url_shell = stdlib::shell_escape("https://pgp.mongodb.com/server-${version}.asc")

    # Install mongodb repo
    exec { 'package_mongodb_source':
      command => "/usr/bin/printf %b ${source_shell} > ${file_shell}; /usr/bin/curl -fsSL ${key_url_shell} | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
    }

    # Install mongodb-org-server package
    package { 'mongodb-org-server':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => Exec['package_mongodb_source'],
    }
  } else {
    # Remove mongodb-org-server package
    package { 'mongodb-org-server':
      ensure => purged,
    }

    # Remove mongodb repo
    exec { 'package_mongodb_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => [Package['apt', 'mongodb-org-server']],
    }

    # Remove Gitlab key
    file { 'package_mongodb_key':
      ensure => absent,
      path   => $key,
    }
  }
}
