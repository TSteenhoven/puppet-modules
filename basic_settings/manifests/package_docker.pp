# @summary Manages the Docker upstream APT repository.
#
# This private helper writes or removes the Docker APT source and signing key, supporting both classic `.list` files and
# deb822 `.sources` files. It is called by `basic_settings` after OS support has been calculated.
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_docker':
#     deb_version => 'list',
#     enable      => true,
#     os_name     => 'bookworm',
#     os_parent   => 'debian',
#   }
#
# @param deb_version
#   APT source format to manage: `list` or `822`.
#
# @param enable
#   Creates the repository and imports its key when `true`; removes both when `false`.
#
# @param os_name
#   Distribution codename used in the repository suite.
#
# @param os_parent
#   Distribution family used in the repository URL, such as `debian` or `ubuntu`.
#
# @api private
class basic_settings::package_docker (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    # Use the .sources filename for a deb822 repository definition.
    $file = '/etc/apt/sources.list.d/docker.sources'
  } else {
    # Use the .list filename for a one-line APT repository definition.
    $file = '/etc/apt/sources.list.d/docker.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/docker.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  # Install the Docker repository when enabled and remove its managed source otherwise.
  if ($enable) {
    # Set url
    $url = "https://download.docker.com/linux/${os_parent}"

    # Get source
    if ($deb_version == '822') {
      # Render the selected repository and signing key in deb822 format.
      $source  = "Types: deb\\nURIs: ${url}\\nSuites: ${os_name}\\nComponents: stable\\nSigned-By:${key}\\n"
    } else {
      # Render the selected repository and signing key in one-line APT format.
      $source = "deb [signed-by=${key}] ${url} ${os_name} stable\\n"
    }

    # Escape generated repo content as literal newline sequences and key URL before the shell writes or fetches them.
    $source_shell = stdlib::shell_escape("# Managed by puppet\\n${source}")
    $key_url_shell = stdlib::shell_escape("${url}/gpg")

    # Install docker repo
    exec { 'package_docker_source':
      command => "/usr/bin/printf %b ${source_shell} > ${file_shell}; /usr/bin/curl -fsSL ${key_url_shell} | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
    }
  } else {
    # Remove docker repo
    exec { 'package_docker_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt'],
    }

    # Remove docker key
    file { 'package_docker_key':
      ensure => absent,
      path   => $key,
    }
  }
}
