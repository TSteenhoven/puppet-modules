# @summary Writes a sudoers.d rule with repository-standard ownership and mode.
#
# lint:ignore:140chars
# This defined type installs sudo when needed and writes a single sudoers snippet under `/etc/sudoers.d`. It is used by service modules that need controlled command delegation while keeping sudoers files root-owned and mode `0440`.
# lint:endignore
#
# @example Allow a command for a service account
#   basic_settings::login_sudo { 'example':
#     rule => 'example ALL=(root) NOPASSWD: /usr/local/sbin/example',
#   }
#
# @param rule
#   Complete sudoers rule content written below the managed-file header.
#
# @param order
#   Numeric ordering prefix used in the filename. The default is 25.
#
# @api public
define basic_settings::login_sudo (
  String  $rule,
  Integer $order = 25,
) {
  # Check if login class is not defined
  if (!defined(Class['basic_settings::login'])) {
    # Set values
    $prefix = $basic_settings::login::sudoers_prefix

    # Install sudo package
    package { 'sudo':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    # Use the fallback sudoers prefix when no managed sudoers directory is available.
    $prefix = 'z'
  }

  # Create config file
  file { "/etc/sudoers.d/${prefix}${order}-${name}":
    ensure  => file,
    mode    => '0440',
    owner   => 'root',
    group   => 'root',
    content => "# Managed by puppet\n${rule}\n",
    require => Package['sudo'],
  }
}
