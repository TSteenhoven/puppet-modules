class basic_settings::locale (
  Boolean   $enable         = false,
  String    $dictionary     = 'american',
  Boolean   $docs_enable    = false
) {
  # Check if packages are needed
  if ($enable) {
    package { ['dictionaries-common', 'locales', "w${dictionary}"]:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Remove default locale file
    file { '/etc/default/locale':
      ensure  => absent,
    }
  } else {
    # Remove packages
    package { ['dictionaries-common', 'locales', 'wamerican', 'wbritish']:
      ensure  => purged,
    }

    # Install default locale file
    file { '/etc/default/locale':
      ensure  => file,
      mode    => '0644',
      content => "LANG=C.UTF-8\n",
    }
  }

  # Check if docs is needed
  if ($enable and $docs_enable) {
    package { ['manpages', 'manpages-dev', 'man-db']:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    package { ['manpages', 'manpages-dev', 'man-db']:
      ensure  => purged,
    }
  }
}
