# @summary Manages the Mozilla APT repository for Debian or Ubuntu.
#
# lint:ignore:140chars
# This private helper writes or removes the Mozilla package source and signing key. Ubuntu uses the Mozilla Team PPA; other supported systems use `packages.mozilla.org`. It is called by `basic_settings` after platform support has been calculated.
# lint:endignore
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_mozilla':
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
#   Distribution family used to select the correct repository URL.
#
# @api private
class basic_settings::package_mozilla (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/mozilla.sources'
  } else {
    $file = '/etc/apt/sources.list.d/mozilla.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/mozilla.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  # Check if enabled
  if ($enable) {
    # Get variables
    case $os_parent {
      'ubuntu': {
        $url = 'https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu'
      }
      default: {
        $url = 'https://packages.mozilla.org/apt'
      }
    }

    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\\nURIs: ${url}\\nSuites: ${os_name}\\nComponents: main\\nSigned-By:${key}\\n"
    } else {
      $source = "deb [signed-by=${key}] ${url} ${os_name} main\\n"
    }

    # Escape generated repo content as literal newline sequences before the shell writes it.
    $source_shell = stdlib::shell_escape("# Managed by puppet\\n${source}")

    # Add mozilla repo
    case $os_parent {
      'ubuntu': {
        exec { 'package_mozilla_source':
          command => "/usr/bin/printf %b ${source_shell} > ${file_shell}; /usr/bin/curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x738BEB9321D1AAEC13EA9391AEBDF4819BE21867' | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
          unless  => "/usr/bin/test -e ${file_shell}",
          require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
        }
      }
      default: {
        exec { 'package_mozilla_source':
          command => "/usr/bin/printf %b ${source_shell} > ${file_shell}; /usr/bin/curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
          unless  => "/usr/bin/test -e ${file_shell}",
          require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
        }
      }
    }
  } else {
    # Remove sury php repo
    exec { 'package_mozilla_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt'],
    }

    # Remove sury key
    file { 'package_mozilla_key':
      ensure => absent,
      path   => $key,
    }
  }
}
