# @summary Registers monitoring for one or more systemd services.
#
# lint:ignore:140chars
# This defined type installs the shared systemd-service check when needed and creates OpenITCOCKPIT custom-check fragments for the requested service units.
# lint:endignore
# It is used by service modules so monitoring output stays consistent across the repository.
#
# @example Monitor one service
#   basic_settings::monitoring_service { 'nginx': }
#
# @example Monitor several services under one friendly name
#   basic_settings::monitoring_service { 'network':
#     services => ['systemd-networkd', 'systemd-resolved'],
#   }
#
# @param active_days
#   Optional active-day expression passed to the check script.
#
# @param active_windows
#   Optional active-window expression passed to the check script.
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
# @param services
#   Optional list of systemd service names. `undef` monitors the resource title.
#
# @api public
define basic_settings::monitoring_service (
  Optional[String]          $active_days    = undef,
  Optional[String]          $active_windows = undef,
  Enum['present', 'absent'] $ensure         = present,
  Optional[String]          $friendly       = undef,
  Optional[String]          $package        = undef,
  Optional[Array]           $services       = undef,
) {
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
      # Set some values
      $script_path = '/etc/openitcockpit-agent/plugins/check_systemd_service'
      $script_exists = defined(File[$script_path])
      $uid = 'root'
      $gid = 'root'

      # Check services
      if ($services != undef) {
        $services_correct = $services
        if (length($services) == 1) {
          $parent_force = true
        }
      } else {
        $services_correct = $name
        $parent_force = false
      }

      # Create monitoring service parts
      basic_settings::monitoring_service_part { $services_correct:
        ensure         => $ensure,
        package        => 'openitcockpit',
        parent_force   => $parent_force,
        parent_name    => $name,
        script_path    => $script_path,
        friendly       => $friendly_correct,
        active_windows => $active_windows,
        active_days    => $active_days,
      }
    }
    default: {
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
      source => 'puppet:///modules/basic_settings/monitoring/check_systemd_service',
      owner  => $uid,
      group  => $gid,
      mode   => '0700',
    }

    # Create sudo
    if ($uid != 'root') {
      $sudo_cmnd = regsubst("monitoring_service_${name}", '[^A-Za-z0-9]', '_', 'G').upcase
      file { "/etc/sudoers.d/${sudoers_prefix}25-monitoring_service_${name}":
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
