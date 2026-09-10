# @summary Manages console assistant packages and local keyboard configuration.
#
# lint:ignore:140chars
# This class removes desktop assistant packages that are not useful on hardened servers, optionally installs audio support, and manages `/etc/default/keyboard` and `/etc/default/console-setup`. Keyboard configuration is enabled by default on physical hosts and disabled by default on virtual machines unless explicitly overridden.
# lint:endignore
#
# @example Use the default server-oriented assistant settings
#   include basic_settings::assistent
#
# @param audio_enable
#   Installs PipeWire audio packages when `true`; purges them when `false`.
#   The default is `false` because most managed servers do not need audio.
#
# @param keyboard_codeset
#   Console codeset written to the console setup template. The default is `Lat15`.
#
# @param keyboard_enable
#   Controls whether keyboard packages and console configuration are managed.
#   `undef` uses the host type default, `true` forces management on, and `false` purges the keyboard packages and `/etc/console-setup`.
#
# @param keyboard_layout
#   Keyboard layout written to `/etc/default/keyboard`. The default is `us`.
#
# @api public
class basic_settings::assistent (
  Boolean           $audio_enable     = false,
  String            $keyboard_codeset = 'Lat15',
  Optional[Boolean] $keyboard_enable  = undef,
  String            $keyboard_layout  = 'us',
) {
  # Remove unnecessary packages
  package { 'at-spi2-core':
    ensure => purged,
  }

  # Install packages
  package { ['bash-completion']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Manage the audio stack separately from the desktop assistant packages.
  if ($audio_enable) {
    # Install audio packages
    package {['pipewire-pulse', 'wireplumber']:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    # Remove audio packages
    package { ['pipewire-pulse', 'wireplumber']:
      ensure => purged,
    }
  }

  # Get keyboard state
  if ($keyboard_enable == undef) {
    # Enable local keyboard support by default on physical hosts.
    $keyboard_enable_correct = !$facts['is_virtual']
  } else {
    # Honor the explicit keyboard setting, including on virtual hosts.
    $keyboard_enable_correct = $keyboard_enable
  }

  # Check if we need to install keyboard packages
  if ($keyboard_enable_correct) {
    # Install packages
    package { ['console-setup', 'keyboard-configuration']:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Reload keyboard
    exec { 'assistent_keyboard_reload':
      command     => '/usr/bin/setupcon',
      refreshonly => true,
    }

    # Create keyboard config
    file { '/etc/default/keyboard':
      ensure  => file,
      content => template('basic_settings/assistent/keyboard'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      notify  => Exec['assistent_keyboard_reload'],
    }

    # Create console-setup config
    file { '/etc/default/console-setup':
      ensure  => file,
      content => template('basic_settings/assistent/console-setup'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      notify  => Exec['assistent_keyboard_reload'],
    }
  } else {
    # Remove unnecessary packages
    package { ['console-setup', 'keyboard-configuration']:
      ensure => purged,
    }

    # Remove dir
    file { '/etc/console-setup':
      ensure  => absent,
      recurse => true,
      purge   => true,
      force   => true,
      require => Package['console-setup'],
    }
  }
}
