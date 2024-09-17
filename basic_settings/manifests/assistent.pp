class basic_settings::assistent (
  String $keyboard_layout = 'us',
  String $keyboard_codeset = 'Lat15'
) {
  # Remove unnecessary packages
  package { 'at-spi2-core':
    ensure  => purged,
  }

  # Install packages
  package { ['bash-completion']:
    ensure  => installed,
  }

  # Check if this server is virtual
  if ($facts['is_virtual']) {
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
  } else {
    # Install packages
    package { ['console-setup', 'keyboard-configuration']:
      ensure  => installed,
    }

    # Reload keyboard
    exec { 'assistent_keyboard_reload':
      command     => '/usr/bin/setupcon',
      refreshonly => true,
    }

    # Create keyboard config
    file { '/etc/default/keyboard':
      ensure => file,
      source => 'puppet:///modules/basic_settings/assistent/keyboard',
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      notify => Exec['assistent_keyboard_reload'],
    }

    # Create console-setup config
    file { '/etc/default/console-setup':
      ensure => file,
      source => 'puppet:///modules/basic_settings/assistent/console-setup',
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      notify => Exec['assistent_keyboard_reload'],
    }
  }
}
