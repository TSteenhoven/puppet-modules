# @summary Manages console assistant packages and local keyboard configuration.
#
# lint:ignore:140chars
# This class removes desktop assistant packages that are not useful on hardened servers, optionally installs audio support, and manages `/etc/default/keyboard` and `/etc/default/console-setup`. It also manages keyboard debconf answers when `Package['debconf']` has already been declared. Keyboard configuration is enabled by default on physical hosts and disabled by default on virtual machines unless explicitly overridden.
# lint:endignore
#
# @example Use the default server-oriented assistant settings
#   include basic_settings::assistent
#
# @example Enable keyboard package and configuration management on a virtual machine
#   class { 'basic_settings::assistent':
#     keyboard_enable => true,
#   }
#
# @param audio_enable
#   Installs PipeWire audio packages when `true`; purges them when `false`.
#   The default is `false` because most managed servers do not need audio.
#
# @param keyboard_codeset
#   Console codeset identifier written to the console setup template. The default is `Lat15`.
#
# @param keyboard_enable
#   Controls installation of console-setup and keyboard-configuration and management of their debconf answers and configuration.
#   `undef` uses the host type default, `true` forces management on, and `false` purges the keyboard packages and `/etc/console-setup`.
#   Debconf answers are managed only when `Package['debconf']` is already declared; packages and files are managed independently.
#   Does not declare a keyboard reload or console service restart for configuration changes.
#
# @param keyboard_layout
#   XKB layout or comma-separated layouts written to debconf and `/etc/default/keyboard`. The default is `us`.
#
# @api public
class basic_settings::assistent (
  Boolean                                   $audio_enable     = false,
  Pattern[/\A[A-Za-z0-9_-]+\z/]             $keyboard_codeset = 'Lat15',
  Optional[Boolean]                         $keyboard_enable  = undef,
  Pattern[/\A[a-z0-9_]+(?:,[a-z0-9_]+)*\z/] $keyboard_layout  = 'us',
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

  # Keep debconf and the persistent configuration aligned without reloading the active console.
  if ($keyboard_enable_correct) {
    # Preserve the existing right-Alt behavior in both configuration interfaces.
    $keyboard_options = $keyboard_codeset ? {
      'Lat15' => 'lv3:ralt_switch,compose:ralt',
      default => '',
    }

    # Enabled keyboard management always includes the console packages.
    package { ['console-setup', 'keyboard-configuration']:
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Preseed before installation, and write the managed configuration after package installation has completed.
    $keyboard_package_require = [Package['console-setup', 'keyboard-configuration']]

    # Preseed only when an explicit debconf package dependency is available in the catalog.
    if (defined(Package['debconf'])) {
      # Empty variants and the selected options must also replace previously stored answers.
      $keyboard_answers = {
        'modelcode'   => 'pc105',
        'layoutcode'  => $keyboard_layout,
        'variantcode' => '',
        'optionscode' => $keyboard_options,
        'xkb-keymap'  => $keyboard_layout,
      }
      $keyboard_answers.each |String $item, String $value| {
        # debconf stores the complete keymap as a selection and the individual XKB fields as strings.
        $answer_type = $item ? { 'xkb-keymap' => 'select', default => 'string' }

        # Mark each answer as seen to prevent future interactive package questions.
        debconf { "keyboard-configuration/${item}":
          type    => $answer_type,
          value   => $value,
          seen    => true,
          before  => $keyboard_package_require,
          require => Package['debconf'],
        }
      }
    }

    # Create keyboard config
    file { '/etc/default/keyboard':
      ensure  => file,
      content => template('basic_settings/assistent/keyboard'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => $keyboard_package_require,
    }

    # Create console-setup config
    file { '/etc/default/console-setup':
      ensure  => file,
      content => template('basic_settings/assistent/console-setup'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => $keyboard_package_require,
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
