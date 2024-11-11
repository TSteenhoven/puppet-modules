class basic_settings::development (
  Optional[Integer]   $gcc_version        = undef,
  Array               $install_options    = []
) {
  # Remove unnecessary packages
  package { 'lxd-installer':
    ensure  => purged,
  }

  # Install default development packages
  package { ['build-essential', 'python-is-python3', 'python3', 'nano', 'ruby', 'screen']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Set default rules
  $default_rules = ['/usr/bin/gcc', '/usr/bin/git', '/usr/bin/gmake', '/usr/bin/make']

  # Check if no gcc version is given
  if ($gcc_version == undef) {
    # Install gcc packages
    package { 'gcc':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Create list of packages that is suspicious
    $suspicious_packages = $default_rules
  } else {
    # Install gcc packages
    package { ['gcc', "gcc-${gcc_version}"]:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Remove other gcc packages
    case $gcc_version { #lint:ignore:case_without_default
      14: {
        package { ['gcc-12', 'gcc-10']:
          ensure  => purged,
        }
      }
      12: {
        package { ['gcc-14', 'gcc-10']:
          ensure  => purged,
        }
      }
    }

    # Create list of packages that is suspicious
    $suspicious_packages = flatten($default_rules, ["/usr/bin/gcc-${gcc_version}"])
  }

  # Install packages
  package { 'git':
    ensure          => installed,
    install_options => union($install_options, ['--no-install-recommends', '--no-install-suggests']]),
  }

  # Setup audit rules
  if (defined(Package['auditd'])) {
    basic_settings::security_audit { 'development':
      rule_suspicious_packages => $suspicious_packages,
    }
  }
}
