# @summary Manages the NodeSource APT repository and Node.js package.
#
# lint:ignore:140chars
# This private helper writes or removes the NodeSource APT source and signing key, installs or purges `nodejs`, refreshes APT on repository changes, restricts npm and npx execution to the `nodejs` group, and adds audit coverage for npm-related tooling when auditd is present.
# lint:endignore
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_node':
#     deb_version => 'list',
#     enable      => true,
#     version     => 20,
#   }
#
# @param deb_version
#   APT source format to manage: `list` or `822`.
#
# @param enable
#   Creates the repository, imports its key, and installs Node.js when `true`; removes them when `false`.
#
# @param version
#   Node.js major version used in the NodeSource repository URL. The default is 20.
#
# @api private
class basic_settings::package_node (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  Integer             $version     = 20,
) {
  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/nodesource.sources'
  } else {
    $file = '/etc/apt/sources.list.d/nodesource.list'
  }

  # Set repository and permission-helper paths.
  $key = '/usr/share/keyrings/nodesource.gpg'
  $npm_permission_helper_path = '/usr/local/lib/puppet/package-node-npm-permissions'

  # Escape managed paths before shell commands and guards use them.
  $key_shell = stdlib::shell_escape($key)
  $npm_permission_helper_path_shell = stdlib::shell_escape($npm_permission_helper_path)

  # Refresh the APT cache only after the managed repo state changes.
  exec { 'package_node_source_reload':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
    require     => Package['apt'],
  }

  if ($enable) {
    # The nodejs group is the local authorization boundary for running npm and npx without giving package-management rights.
    group { 'nodejs':
      ensure => present,
      system => true,
    }

    # Get source
    if ($deb_version == '822') {
      $source = "Types: deb\nURIs: https://deb.nodesource.com/node_${version}.x\nSuites: nodistro\nComponents: main\nSigned-By:${key}\n"
    } else {
      $source = "deb [signed-by=${key}] https://deb.nodesource.com/node_${version}.x nodistro main\n"
    }

    # Manage the NodeSource APT source explicitly instead of executing an upstream shell bootstrap.
    file { 'package_node_source':
      ensure  => file,
      path    => $file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "# Managed by puppet\n${source}",
      notify  => Exec['package_node_source_reload'],
      require => Package['apt'],
    }

    # Download and install the repository signing key in a dedicated keyring file.
    exec { 'package_node_key':
      command => "/usr/bin/curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor | tee ${key_shell} >/dev/null; chmod 644 ${key_shell}", # lint:ignore:140chars
      unless  => "/usr/bin/test -e ${key_shell}",
      notify  => Exec['package_node_source_reload'],
      require => [Package['apt'], Package['apt-transport-https'], Package['curl'], Package['gnupg']],
    }

    # Install Node.js only after the managed source and key have been applied.
    package { 'nodejs':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
      require         => [File['package_node_source'], Exec['package_node_key'], Exec['package_node_source_reload']],
    }

    # Ensure the shared Puppet helper directory exists before installing the npm permission helper.
    if (!defined(File['/usr/local/lib/puppet'])) {
      file { '/usr/local/lib/puppet':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755' # Helper scripts stored here need to be reachable by Puppet-managed commands.
      }
    }

    # Install the permission helper separately so the recursive mode logic stays reviewable and avoids npm or npx execution.
    file { $npm_permission_helper_path:
      ensure  => file,
      source  => 'puppet:///modules/basic_settings/package_node/npm-permissions',
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      require => File['/usr/local/lib/puppet'],
    }

    # Keep the npm package tree root-owned while granting the nodejs group only read and execute access needed by npm and npx.
    exec { 'package_node_npm_permissions':
      command => $npm_permission_helper_path_shell,
      unless  => "${npm_permission_helper_path_shell} --check",
      require => [Group['nodejs'], Package['nodejs'], File[$npm_permission_helper_path]],
    }

    # Create list of packages that is suspicious
    $suspicious_packages = ['/usr/local/npm']

    # Setup audit rules
    if (defined(Package['auditd'])) {
      basic_settings::security_audit { 'node':
        rule_suspicious_packages => $suspicious_packages,
      }
    }
  } else {
    # Remove nodejs package
    package { 'nodejs':
      ensure => purged,
    }

    # Remove the local npm permission helper when Node.js package management is disabled.
    file { $npm_permission_helper_path:
      ensure => absent,
    }

    # Remove the managed NodeSource repo file when the feature is disabled.
    file { 'package_node_source':
      ensure  => absent,
      path    => $file,
      notify  => Exec['package_node_source_reload'],
      require => [Package['apt'], Package['nodejs']],
    }

    # Remove the matching keyring so the disabled repo leaves no trusted signing material behind.
    file { 'package_node_key':
      ensure  => absent,
      path    => $key,
      notify  => Exec['package_node_source_reload'],
      require => [Package['apt'], Package['nodejs']],
    }
  }
}
