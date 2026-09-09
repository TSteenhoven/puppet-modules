# @summary Manages the GitLab EE upstream APT repository.
#
# lint:ignore:140chars
# This private helper writes or removes the GitLab package source and signing key. It is called by `basic_settings` after OS support has been calculated.
# lint:endignore
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_gitlab':
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
class basic_settings::package_gitlab (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/gitlab.sources'
  } else {
    $file = '/etc/apt/sources.list.d/gitlab.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/gitlab.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\\nURIs: https://packages.gitlab.com/gitlab/gitlab-ee/${os_parent}\\nSuites: ${os_name}\\nComponents: main\\nSigned-By:${key}\\n" # lint:ignore:140chars
    } else {
      $source = "deb [signed-by=${key}] https://packages.gitlab.com/gitlab/gitlab-ee/${os_parent} ${os_name} main\\n"
    }

    # Escape generated repo content as literal newline sequences before the shell writes it.
    $source_shell = stdlib::shell_escape("# Managed by puppet\\n${source}")

    # Install Gitlab repo
    exec { 'package_gitlab_source':
      command => "/usr/bin/printf %b ${source_shell} > ${file_shell}; /usr/bin/curl -fsSL https://packages.gitlab.com/gitlab/gitlab-ee/gpgkey | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt', 'apt-transport-https', 'curl', 'gnupg'],
    }
  } else {
    # Remove Nginx repo
    exec { 'package_gitlab_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt'],
    }

    # Remove Gitlab key
    file { 'package_gitlab_key':
      ensure => absent,
      path   => $key,
    }
  }
}
