# @summary Registers a custom monitoring script with the configured monitoring backend.
#
# This defined type writes or removes a root-owned plugin script and registers it in OpenITCOCKPIT `customchecks.ini`
# when that backend is active. It centralizes plugin file permissions, scheduling metadata, and optional sudoers support
# for checks that need elevated privileges.
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
#   Controls whether the plugin script and registration are present or absent. `absent` also removes an old script with
#   backend `none`.
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
# @param register
#   Registers a runnable check when true. Set false to manage one shared script without creating a check for the script
#   itself.
#
# @param root_required
#   Indicates whether the check requires root privileges. When a non-root plugin owner is used by a backend, this
#   controls sudoers generation.
#
# @param script
#   Title of another monitoring_custom resource that owns the shared script; only letters, digits, underscores, dots and
#   hyphens are accepted. `undef` manages this check own script. With a title, this resource only registers arguments
#   and never creates or removes the shared file; source and content must remain undef. The owner supplies its backend
#   path and file dependency through this type.
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
  Boolean                   $register      = true,
  Boolean                   $root_required = true,
  Optional[String[1]]       $script        = undef,
  Optional[String]          $source        = undef,
  Integer                   $timeout       = 30,
) {
  # Keep valid input on the main path so validation failures stay exceptional.
  if (($source == undef or $content == undef) and ($script == undef or ($source == undef and $content == undef))) {
    # Validate the executable source and shared-script identifier before registering the check.
    if (($source == undef or $source =~ /(?i:\A(?:puppet:\/\/\/|file:\/\/\/|https:\/\/))/)
      and ($script == undef or $script =~ /\A[A-Za-z0-9_.-]+\z/)) {
      # Get friendly name
      if ($friendly == undef) {
        # Derive a readable monitoring label from the resource title.
        $friendly_correct = capitalize($name)
      } else {
        # Use the caller's monitoring label.
        $friendly_correct = $friendly
      }

      # Try to get package
      if (defined(Class['basic_settings::monitoring'])) {
        # Inherit the central monitoring backend unless this registration selects one.
        if ($package == undef) {
          # Inherit the monitoring backend selected by the central monitoring class.
          $package_correct = $basic_settings::monitoring::package
        } else {
          # Use the explicitly selected monitoring backend.
          $package_correct = $package
        }
        $sudoers_dir_enable = $basic_settings::monitoring::sudoers_dir_enable
      } else {
        # Disable backend registration and sudoers integration without monitoring configuration.
        $package_correct = 'none'
        $sudoers_dir_enable = false
      }

      # Get sudoers prefix
      if ($sudoers_dir_enable) {
        # Use unprefixed fragments in the managed sudoers directory.
        $sudoers_prefix = ''
      } else {
        # Use the fallback sudoers prefix when no managed sudoers directory is available.
        $sudoers_prefix = 'z'
      }

      # Do thing based on package
      $file_ensure = $ensure ? { 'present' => 'file', default => $ensure }
      case $package_correct {
        'openitcockpit': {
          # Resolve this registration's name and the path of its own or shared executable.
          $script_name = "check_${name}"
          $script_owner = $script ? { undef => $name, default => $script }
          $script_path = "/etc/openitcockpit-agent/plugins/check_${script_owner}"

          # Keep the monitoring executable outside the control of unprivileged users.
          $uid = 'root'
          $gid = 'root'

          # Append caller arguments only when this registration supplies them.
          if ($cmd == undef or $cmd == '') {
            # Invoke the check directly when no extra arguments are supplied.
            $command = $script_path
          } else {
            # Append the supplied arguments to the check executable.
            $command = "${script_path} ${cmd}"
          }

          # Create fragment for plugin
          if ($ensure == present and $register) {
            concat::fragment { "monitoring_plugin_${name}":
              target  => '/etc/openitcockpit-agent/customchecks.ini',
              content => "\n[${script_name}] # ${friendly_correct}\ncommand = ${command}\ninterval = ${interval}\ntimeout = ${timeout}\nenabled = true\n", # lint:ignore:140chars
              order   => '10',
              require => File[$script_path],
            }
          }
        }
        default: {
          # Cleanup must retain the backend-owned path even after monitoring has been disabled.
          $script_path = $ensure ? {
            absent  => "/etc/openitcockpit-agent/plugins/check_${name}",
            default => undef,
          }
          $uid = 'root'
          $gid = 'root'
        }
      }

      # Check if script path is not defined
      if ($script_path != undef and $script == undef) {
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
          # Provide sudo once when an active privileged check needs it.
          if ($ensure == present and !defined(Package['sudo'])) {
            package { 'sudo':
              ensure          => installed,
              install_options => ['--no-install-recommends', '--no-install-suggests'],
            }
          }
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
      fail('basic_settings::monitoring_custom requires an approved source URL and a shared script title containing only letters, digits, dots, underscores or hyphens.') # lint:ignore:140chars
    }
  } else {
    fail('basic_settings::monitoring_custom accepts source or content, not both; shared scripts accept neither.')
  }
}
