# @summary Manages locale, dictionary, and optional documentation packages.
#
# lint:ignore:140chars
# This class keeps the server locale minimal by default. When enabled, it installs locale and dictionary packages and removes the static default locale file. When disabled, it purges locale dictionaries and writes `LANG=C.UTF-8` to `/etc/default/locale`.
# lint:endignore
#
# @example Keep the minimal default locale
#   include basic_settings::locale
#
# @example Enable British dictionaries and manual pages
#   class { 'basic_settings::locale':
#     dictionary  => 'british',
#     docs_enable => true,
#     enable      => true,
#   }
#
# @param dictionary
#   Dictionary package suffix used as `w<dictionary>` when locale support is enabled. The default is `american`.
#
# @param docs_enable
#   Installs manual page packages when `true` and `enable` is also `true`.
#   Otherwise those documentation packages are purged.
#
# @param enable
#   Enables full locale package management when `true`; keeps the minimal `C.UTF-8` setup when `false`.
#
# @api public
class basic_settings::locale (
  String  $dictionary  = 'american',
  Boolean $docs_enable = false,
  Boolean $enable      = false,
) {
  # Check if packages are needed
  if ($enable) {
    package { ['dictionaries-common', 'locales', "w${dictionary}"]:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Remove default locale file
    file { '/etc/default/locale':
      ensure => absent,
    }
  } else {
    # Remove packages
    package { ['dictionaries-common', 'locales', 'wamerican', 'wbritish']:
      ensure => purged,
    }

    # Install default locale file
    file { '/etc/default/locale':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
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
      ensure => purged,
    }
  }
}
