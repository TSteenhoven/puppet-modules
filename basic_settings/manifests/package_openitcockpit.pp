# @summary Manages OpenITCOCKPIT server or agent APT repository access.
#
# lint:ignore:140chars
# This private helper writes or removes the OpenITCOCKPIT APT source, signing key, and root-only APT authentication file. It supports server and agent repositories plus stable or nightly channels.
# lint:endignore
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_openitcockpit':
#     deb_version => 'list',
#     enable      => true,
#     os_name     => 'bookworm',
#     os_parent   => 'debian',
#     package     => 'agent',
#   }
#
# @param deb_version
#   APT source format to manage: `list` or `822`.
#
# @param enable
#   Creates repository/authentication files and imports the key when `true`; removes them when `false`.
#
# @param os_name
#   Distribution codename used by the server repository.
#
# @param os_parent
#   Distribution family retained for consistency with repository helpers.
#
# @param package
#   OpenITCOCKPIT repository family to manage: usually `agent` or `server`.
#
# @param license
#   Optional repository license token. `undef` uses the community license token currently encoded by the module.
#
# @param nightly
#   Uses the nightly repository channel when `true`; otherwise uses stable.
#
# @api private
class basic_settings::package_openitcockpit (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
  String              $package,
  Optional[String]    $license     = undef,
  Boolean             $nightly     = false,
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    # Use the .sources filename for a deb822 repository definition.
    $file = '/etc/apt/sources.list.d/openitcockpit.sources'
  } else {
    # Use the .list filename for a one-line APT repository definition.
    $file = '/etc/apt/sources.list.d/openitcockpit.list'
  }

  # Set keyrings file
  $key = '/usr/share/keyrings/openitcockpit.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_shell = stdlib::shell_escape($file)
  $key_shell = stdlib::shell_escape($key)

  # Install the selected OpenITCOCKPIT repository or remove its managed source when disabled.
  if ($enable) {
    # Check if package is server or agent
    if ($package == 'server') {
      # Set url
      if ($nightly) {
        # Select the nightly package channel.
        $url = "https://packages5.openitcockpit.io/openitcockpit/${os_name}/nightly"
      } else {
        # Select the stable package channel.
        $url = "https://packages5.openitcockpit.io/openitcockpit/${os_name}/stable"
      }

      # Get source
      if ($deb_version == '822') {
        # Render the selected repository and signing key in deb822 format.
        $source  = "Types: deb\\nURIs: ${url}\\nSuites: ${os_name}\\nComponents: main\\nSigned-By:${key}\\n"
      } else {
        # Render the selected repository and signing key in one-line APT format.
        $source = "deb [signed-by=${key}] ${url} ${os_name} main\\n"
      }
    } else {
      # Set url
      if ($nightly) {
        # Select the nightly package channel.
        $url = 'https://packages5.openitcockpit.io/openitcockpit-agent/deb/nightly'
      } else {
        # Select the stable package channel.
        $url = 'https://packages5.openitcockpit.io/openitcockpit-agent/deb/stable'
      }

      # Get source
      if ($deb_version == '822') {
        # Render the selected repository and signing key in deb822 format.
        $source  = "Types: deb\\nURIs: ${url}\\nSuites: deb\\nComponents: main\\nSigned-By:${key}\\n"
      } else {
        # Render the selected repository and signing key in one-line APT format.
        $source = "deb [signed-by=${key}] ${url} deb main\\n"
      }
    }

    # Get license
    if ($license == undef) {
      # Use the community repository license when none is supplied.
      $license_correct = 'e5aef99e-817b-0ff5-3f0e-140c1f342792' #Community
    } else {
      # Keep the caller's repository license selection.
      $license_correct = $license
    }

    # Escape generated repo content as literal newline sequences before the shell writes it.
    $source_shell = stdlib::shell_escape("# Managed by puppet\\n${source}")

    # Install openitcockpit license
    file { 'package_openitcockpit_license':
      ensure  => file,
      path    => '/etc/apt/auth.conf.d/openitcockpit.conf',
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => Sensitive.new("machine packages5.openitcockpit.io login secret password ${license_correct}\n"),
      require => Package['apt', 'apt-transport-https'],
    }

    # Install openitcockpit repo
    exec { 'package_openitcockpit_source':
      command => "/usr/bin/printf %b ${source_shell} > ${file_shell}; /usr/bin/curl -fsSL https://packages5.openitcockpit.io/repokey.txt | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_shell}",
      require => [File['package_openitcockpit_license'], Package['curl']],
    }
  } else {
    # Remove openitcockpit license
    file { 'package_openitcockpit_license':
      ensure => absent,
      path   => '/etc/apt/auth.conf.d/openitcockpit.conf',
    }

    # Remove openitcockpit repo
    exec { 'package_openitcockpit_source':
      command => "/usr/bin/rm ${file_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_shell}",
      require => Package['apt'],
    }

    # Remove openitcockpit key
    file { 'package_openitcockpit_key':
      ensure => absent,
      path   => $key,
    }
  }
}
