# @summary Manages the official Nginx upstream APT repository.
#
# lint:ignore:140chars
# This private helper writes or removes the Nginx mainline package source and signing key. It is called by `basic_settings` after OS support has been calculated.
# lint:endignore
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_nginx':
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
#   Distribution family used in the repository URL.
#
# @api private
class basic_settings::package_nginx (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    # Use the .sources filename for a deb822 repository definition.
    $file = '/etc/apt/sources.list.d/nginx.sources'
  } else {
    # Use the .list filename for a one-line APT repository definition.
    $file = '/etc/apt/sources.list.d/nginx.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/nginx-archive-keyring.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  # Install the Nginx repository when enabled and remove its managed source otherwise.
  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      # Render the selected repository and signing key in deb822 format.
      $source  = "Types: deb\\nURIs: https://nginx.org/packages/mainline/${os_parent}\\nSuites: ${os_name}\\nComponents: nginx\\nSigned-By:${key}\\n" # lint:ignore:140chars
    } else {
      # Render the selected repository and signing key in one-line APT format.
      $source = "deb [signed-by=${key}] https://nginx.org/packages/mainline/${os_parent} ${os_name} nginx\\n"
    }

    # Escape generated repo content as literal newline sequences before the shell writes it.
    $source_shell = stdlib::shell_escape("# Managed by puppet\\n${source}")

    # Install Nginx repo
    exec { 'package_nginx_source':
      command => "/usr/bin/printf %b ${source_shell} > ${file_shell}; /usr/bin/curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
    }
  } else {
    # Remove Nginx repo
    exec { 'package_nginx_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt'],
    }

    # Remove nginx key
    file { 'package_nginx_key':
      ensure => absent,
      path   => $key,
    }
  }
}
