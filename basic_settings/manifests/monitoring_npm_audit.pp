# @summary Registers an npm audit monitoring check for a Node.js working directory.
#
# lint:ignore:140chars
# This defined type adds an OpenITCOCKPIT custom check that runs the shared `check_npm_audit` plugin for one application directory. It is usually created automatically by `basic_settings::systemd_service` when a service starts a Node.js process from a known working directory.
# lint:endignore
#
# @example Monitor a Node.js application directory
#   basic_settings::monitoring_npm_audit { 'frontend':
#     dir => '/opt/frontend',
#   }
#
# @param dir
#   Application directory passed to the npm audit check.
#
# @param ensure
#   Controls whether the check registration is present or absent.
#
# @param friendly
#   Human-readable check name. `undef` uses a capitalized resource title.
#
# @param package
#   Monitoring package override. `undef` inherits `basic_settings::monitoring` when that class is declared.
#
# @api public
define basic_settings::monitoring_npm_audit (
  String                    $dir,
  Enum['present', 'absent'] $ensure   = present,
  Optional[String]          $friendly = undef,
  Optional[String]          $package  = undef,
) {
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

  # Check if sudo package is not defined
  if (!defined(Package['sudo'])) {
    package { 'sudo':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Do thing based on package
  $file_ensure = $ensure ? { 'present' => 'file', default => $ensure }
  case $package_correct {
    'openitcockpit': {
      # Resolve the registration name and check whether the shared executable is already managed.
      $script_name = "check_${name}_npm_audit"
      $script_path = '/etc/openitcockpit-agent/plugins/check_npm_audit'
      $script_exists = defined(File[$script_path])

      # Keep the monitoring executable outside the control of unprivileged users.
      $uid = 'root'
      $gid = 'root'

      # Create fragment for plugin
      if ($ensure == present) {
        concat::fragment { "monitoring_npm_audit_${name}":
          target  => '/etc/openitcockpit-agent/customchecks.ini',
          content => "\n[${script_name}] # ${friendly_correct}\ncommand = ${script_path} -d ${dir} -n ${name}\ninterval = 300\ntimeout = 10\nenabled = true\n", # lint:ignore:140chars
          order   => '10',
        }
      }
    }
    default: {
      # Leave executable and ownership settings unset for an unsupported monitoring backend.
      $script_path = undef
      $script_exists = true
      $uid = undef
      $gid = undef
    }
  }

  # Check if script path is not defined
  if (!$script_exists) {
    # Create script
    file { $script_path:
      ensure => $file_ensure,
      source => 'puppet:///modules/basic_settings/monitoring/check_npm_audit',
      owner  => $uid,
      group  => $gid,
      mode   => '0700',
    }

    # Create sudo
    if ($uid != 'root') {
      # Normalize the resource title into a valid sudo command-alias identifier.
      $sudo_cmnd = regsubst("monitoring_npm_audit_${name}", '[^A-Za-z0-9]', '_', 'G').upcase
      file { "/etc/sudoers.d/${sudoers_prefix}25-monitoring_npm_audit_${name}":
        ensure  => $file_ensure,
        owner   => 'root',
        group   => $gid,
        mode    => '0440',
        content => "# Managed by puppet\nCmnd_Alias ${sudo_cmnd} = ${script_path} * \nDefaults!${sudo_cmnd} !mail_always\n${uid} ALL=(root) NOPASSWD: ${sudo_cmnd}\n", # lint:ignore:140chars
        require => Package['sudo'],
      }
    }
  }
}
