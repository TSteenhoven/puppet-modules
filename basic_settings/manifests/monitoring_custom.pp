# @summary Registers a custom monitoring script with the configured monitoring backend.
#
# lint:ignore:140chars
# This defined type writes or removes a root-owned plugin script and registers it in OpenITCOCKPIT `customchecks.ini` when that backend is active. It centralizes plugin file permissions, scheduling metadata, and optional sudoers support for checks that need elevated privileges.
# lint:endignore
#
# @example Register a custom OpenITCOCKPIT check
#   basic_settings::monitoring_custom { 'example':
#     source   => 'puppet:///modules/profile/check_example',
#     friendly => 'Example service',
#     interval => 300,
#   }
#
# @param cmd
#   Optional arguments appended after the managed script path in the generated command.
#
# @param content
#   Optional inline script content. Mutually exclusive in practice with `source`.
#
# @param ensure
#   Controls whether the plugin script and registration are present or absent.
#
# @param friendly
#   Human-readable check name. `undef` uses a capitalized resource title.
#
# @param interval
#   Check interval in seconds. The default is 300.
#
# @param package
#   Monitoring package override. `undef` inherits `basic_settings::monitoring` when that class is declared.
#
# @param root_required
# lint:ignore:140chars
#   Indicates whether the check requires root privileges. When a non-root plugin owner is used by a backend, this controls sudoers generation.
# lint:endignore
#
# @param source
#   Optional file source for the plugin script. Must start with `puppet:///`, `file:///`, or `https://`.
#
# @param timeout
#   Check timeout in seconds. The default is 30.
#
# @api public
define basic_settings::monitoring_custom (
  Optional[String]          $cmd           = undef,
  Optional[String]          $content       = undef,
  Enum['present', 'absent'] $ensure        = present,
  Optional[String]          $friendly      = undef,
  Integer                   $interval      = 300,
  Optional[String]          $package       = undef,
  Boolean                   $root_required = true,
  Optional[String]          $source        = undef,
  Integer                   $timeout       = 30,
) {
  # Keep valid input on the main path so validation failures stay exceptional.
  if ($source == undef or $content == undef) {
    if ($source == undef or $source =~ /(?i:\A(?:puppet:\/\/\/|file:\/\/\/|https:\/\/))/) {
      # Get friendly name
      if ($friendly == undef) {
        $friendly_correct = capitalize($name)
      } else {
        $friendly_correct = $friendly
      }

      # Try to get package
      if (defined(Class['basic_settings::monitoring'])) {
        if ($package == undef) {
          $package_correct = $basic_settings::monitoring::package
        } else {
          $package_correct = $package
        }
        $sudoers_dir_enable = $basic_settings::monitoring::sudoers_dir_enable
      } else {
        $package_correct = 'none'
        $sudoers_dir_enable = false
      }

      # Get sudoers prefix
      if ($sudoers_dir_enable) {
        $sudoers_prefix = ''
      } else {
        $sudoers_prefix = 'z'
      }

      # Check if sudo package is not defined
      if ($root_required and !defined(Package['sudo'])) {
        package { 'sudo':
          ensure          => installed,
          install_options => ['--no-install-recommends', '--no-install-suggests'],
        }
      }

      # Do thing based on package
      $file_ensure = $ensure ? { 'present' => 'file', default => $ensure }
      case $package_correct {
        'openitcockpit': {
          # Set some values
          $script_name = "check_${name}"
          $script_path = "/etc/openitcockpit-agent/plugins/${script_name}"
          $uid = 'root'
          $gid = 'root'
          if ($cmd == undef or $cmd == '') {
            $command = $script_path
          } else {
            $command = "${script_path} ${cmd}"
          }

          # Create fragment for plugin
          if ($ensure == present) {
            concat::fragment { "monitoring_plugin_${name}":
              target  => '/etc/openitcockpit-agent/customchecks.ini',
              content => "\n[${script_name}] # ${friendly_correct}\ncommand = ${command}\ninterval = ${interval}\ntimeout = ${timeout}\nenabled = true\n", # lint:ignore:140chars
              order   => '10',
            }
          }
        }
        default: {
          $script_path = undef
          $uid = undef
          $gid = undef
        }
      }

      # Check if script path is not defined
      if ($script_path != undef) {
        # Create script
        file { $script_path:
          ensure  => $file_ensure,
          source  => $source,
          content => $content,
          owner   => $uid,
          group   => $gid,
          mode    => '0700',
        }

        # Create sudo
        if ($root_required and $uid != 'root') {
          $sudo_cmnd = regsubst("monitoring_plugin_${name}", '[^A-Za-z0-9]', '_', 'G').upcase
          file { "/etc/sudoers.d/${sudoers_prefix}25-monitoring_plugin_${name}":
            ensure  => $file_ensure,
            owner   => 'root',
            group   => 'root',
            mode    => '0440',
            content => "# Managed by puppet\nCmnd_Alias ${sudo_cmnd} = ${script_path} * \nDefaults!${sudo_cmnd} !mail_always \n${uid} ALL=(root) NOPASSWD: ${sudo_cmnd}\n", # lint:ignore:140chars
            require => Package['sudo'],
          }
        }
      }
    } else {
      fail('basic_settings::monitoring_custom source must start with puppet:///, file:///, or https://')
    }
  } else {
    fail('basic_settings::monitoring_custom accepts source or content, not both.')
  }
}
