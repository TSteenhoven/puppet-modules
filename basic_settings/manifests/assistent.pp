class basic_settings::assistent (
  Optional[Boolean]   $keyboard_enable  = undef,
  String              $keyboard_layout  = 'us',
  String              $keyboard_codeset = 'Lat15'
) {
  # Remove unnecessary packages
  package { 'at-spi2-core':
    ensure  => purged,
  }

  # Install packages
  package { ['bash-completion']:
    ensure          => installed,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }

  # Get keyboard state
  if ($keyboard_enable == undef) {
    $keyboard_enable_correct = !$facts['is_virtual']
  } else {
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
      ensure  => purged,
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
