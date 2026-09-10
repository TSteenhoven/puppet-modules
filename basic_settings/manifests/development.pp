# @summary Installs development tooling and audit coverage for compiler use.
#
# lint:ignore:140chars
# This class installs the small development toolchain used by the repository, optionally pins a GCC version, removes unrelated LXD bootstrap tooling, and registers audit rules for compilers and build tools when auditd is available.
# lint:endignore
# Changing the GCC version can purge other GCC packages that this class knows how to replace.
#
# @example Install the default development tools
#   include basic_settings::development
#
# @example Install a specific GCC version
#   class { 'basic_settings::development':
#     gcc_version => 14,
#   }
#
# @param gcc_version
#   Optional GCC major version to install alongside the generic `gcc` package.
#   `undef` installs only the default GCC package. Supported cleanup logic exists for the versions explicitly handled in the manifest.
#
# @param install_options
# lint:ignore:140chars
#   Additional APT options; an empty array adds no caller options. Mandatory no-recommends and no-suggests flags are appended without deduplication so they remain effective.
# lint:endignore
#
# @api public
class basic_settings::development (
  Optional[Integer] $gcc_version     = undef,
  Array             $install_options = [],
) {
  # Remove unnecessary packages
  package { 'lxd-installer':
    ensure => purged,
  }

  # Install default development packages
  package { ['build-essential', 'python-is-python3', 'python3', 'nano', 'ruby']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Set default rules
  $default_rules = ['/usr/bin/gcc', '/usr/bin/git', '/usr/bin/gmake', '/usr/bin/make']

  # Install a selected GCC version and retire known alternatives, or use the distribution default.
  if ($gcc_version != undef) {
    # Install gcc packages
    package { ['gcc', "gcc-${gcc_version}"]:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Remove other gcc packages
    case $gcc_version {
      16: {
        package { ['gcc-14', 'gcc-12', 'gcc-10']:
          ensure => purged,
        }
      }
      14: {
        package { ['gcc-12', 'gcc-10']:
          ensure => purged,
        }
      }
      12: {
        package { ['gcc-14', 'gcc-10']:
          ensure => purged,
        }
      }
      default: {
        # Other GCC versions have no known obsolete package set to remove.
      }
    }

    # Create list of packages that is suspicious
    $suspicious_packages = flatten($default_rules, ["/usr/bin/gcc-${gcc_version}"])
  } else {
    # Install gcc packages
    package { 'gcc':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Create list of packages that is suspicious
    $suspicious_packages = $default_rules
  }

  # Install packages
  # Keep policy flags last even when caller options contain duplicate or conflicting flags.
  package { 'git':
    ensure          => installed,
    install_options => concat($install_options, ['--no-install-recommends', '--no-install-suggests']),
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'development':
      rule_suspicious_packages => $suspicious_packages,
    }
  }
}
