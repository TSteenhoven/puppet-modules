# @summary Manages a root-owned logrotate snippet.
#
# This defined type writes `/etc/logrotate.d/<title>` from the module template and ensures the logrotate package and
# configuration directory exist when they are not already managed. It centralizes the repository's secure logrotate file
# ownership and mode defaults.
#
# @example Rotate an application log daily
#   basic_settings::io_logrotate { 'example-app':
#     frequency => 'daily',
#     path      => '/var/log/example/*.log',
#   }
#
# @param frequency
#   Rotation frequency accepted by logrotate. Valid values are `daily`, `weekly`, or `monthly`.
#
# @param path
#   One or more log paths rendered into the logrotate stanza. Multiline strings may be used for multiple paths.
#
# @param compress
#   Enables log compression when `true`. The default is `true`.
#
# @param compress_delay
#   Enables delayed compression when `true`, leaving the most recent rotated log uncompressed. The default is `false`.
#
# @param create_group
#   Group used by the logrotate `create` directive. The default is `root`.
#
# @param create_mode
#   Mode used by the logrotate `create` directive. The default is `600`.
#
# @param create_user
#   Optional user used by the logrotate `create` directive. When omitted, the template uses the module default behavior.
#
# @param ensure
#   Controls whether the logrotate snippet is present or absent.
#
# @param rotate
#   Optional rotation count. `undef` inherits `basic_settings::io::log_rotate` when available, otherwise it falls back
#   to 12.
#
# @param rotate_copy
#   Enables copy-based rotation when `true`. The default is `false`.
#
# @param rotate_post
#   Optional post-rotate script body rendered into the stanza.
#
# @param skip_empty
#   Skips empty log files when `true`. The default is `true`.
#
# @param skip_missing
#   Ignores missing log files when `true`. The default is `true`.
#
# @api public
define basic_settings::io_logrotate (
  Enum['daily', 'weekly', 'monthly'] $frequency,
  String                             $path,
  Boolean                            $compress       = true,
  Boolean                            $compress_delay = false,
  String                             $create_group   = 'root',
  String                             $create_mode    = '600',
  Optional[String]                   $create_user    = undef,
  Enum['present', 'absent']          $ensure         = present,
  Optional[Integer]                  $rotate         = undef,
  Boolean                            $rotate_copy    = false,
  Optional[String]                   $rotate_post    = undef,
  Boolean                            $skip_empty     = true,
  Boolean                            $skip_missing   = true,
) {
  # Check if logrotate package is not defined
  if (!defined(Package['logrotate'])) {
    package { 'logrotate':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Check if this dir is not already managed by puppet
  if (!defined(File['/etc/logrotate.d'])) {
    file { '/etc/logrotate.d':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      require => Package['logrotate'],
    }
  }

  # Get rotate
  if ($rotate == undef) {
    # Inherit central retention when available, otherwise use the standalone default.
    if (defined(Class['basic_settings::io'])) {
      # Inherit the central log-retention count.
      $rotate_correct = $basic_settings::io::log_rotate
    } else {
      # Keep twelve rotations when no central retention policy is available.
      $rotate_correct = 12
    }
  } else {
    # Preserve the caller's log-retention count.
    $rotate_correct = $rotate
  }

  # Enable sharedscripts whenever a postrotate hook runs with a create user.
  if ($create_user != undef and $path =~ '.*') {
    # Run rotation scripts once for the complete log group.
    $shared_scripts = true
  } else {
    # Keep rotation scripts scoped to individual logs.
    $shared_scripts = false
  }

  # Create configuration
  file { "/etc/logrotate.d/${title}":
    ensure  => $ensure,
    content => template('basic_settings/io/logrotate'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => Package['logrotate'],
  }
}
