# @summary Manages the Proxmox VE no-subscription APT repository.
#
# lint:ignore:140chars
# This private helper writes or removes the Proxmox VE package source and signing key. It is called by `basic_settings` after OS support has been calculated.
# lint:endignore
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_proxmox':
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
#   Distribution family retained for consistency with repository helpers.
#
# @api private
class basic_settings::package_proxmox (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/proxmox.sources'
  } else {
    $file = '/etc/apt/sources.list.d/proxmox.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/proxmox.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\\nURIs: http://download.proxmox.com/debian/pve\\nSuites: ${os_name}\\nComponents: pve-no-subscription\\nSigned-By:${key}\\n" # lint:ignore:140chars
    } else {
      $source = "deb [signed-by=${key}] http://download.proxmox.com/debian/pve ${os_name} pve-no-subscription\\n"
    }

    # Escape generated repo content as literal newline sequences and key URL before the shell writes or fetches them.
    $source_shell = stdlib::shell_escape("# Managed by puppet\\n${source}")
    $key_url_shell = stdlib::shell_escape("https://enterprise.proxmox.com/debian/proxmox-release-${os_name}.gpg")

    # Install proxmox repo
    exec { 'package_proxmox_source':
      command => "/usr/bin/printf %b ${source_shell} > ${file_shell}; /usr/bin/curl -fsSLo ${key_shell} ${key_url_shell}; chmod 644 ${key_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
    }
  } else {
    # Remove proxmox repo
    exec { 'package_proxmox_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt'],
    }

    # Remove proxmox key
    file { 'package_proxmox_key':
      ensure => absent,
      path   => $key,
    }
  }
}
