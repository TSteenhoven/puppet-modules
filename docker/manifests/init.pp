# @summary Installs Docker and the shared Compose runtime and monitoring tools.
#
# This class installs Docker CE, Compose, shared exec and backup scripts, and the Compose monitoring executable.
# All docker::compose* definitions require this parent class, including when retiring a project.
# Repository setup is expected to be handled separately, commonly through `basic_settings` with `docker_enable => true`.
#
# @example Install Docker CE
#   class { 'docker': }
#
# @param edition
#   Docker edition to install. The only supported value is `ce`, which installs the `docker-ce` package.
#
# @api public
class docker (
  Enum['ce'] $edition = 'ce',
) {
  # Install the package only for the supported Docker edition.
  if ($edition == 'ce') {
    # Resolve the Docker CE package name for the shared package resource.
    $package_name = 'docker-ce'

    # Set some values
    $monitoring_enable = defined(Class['basic_settings::monitoring'])

    # Check if we have network class
    if (!defined(Class['basic_settings::network'])) {
      # Inherit IP policy from the kernel class when no central network class owns it.
      if (defined(Class['basic_settings::kernel'])) {
        # Keep Docker networks aligned with the kernel's IP policy.
        $ip_version = $basic_settings::kernel::ip_version
      } else {
        # Enable both IP families when no central IP policy is available.
        $ip_version = 'all'
      }
    } else {
      # Prefer the central network class's IP policy for Docker networks.
      $ip_version = $basic_settings::network::ip_version
    }

    # Install Docker from the separately managed repository.
    package { 'docker':
      ensure          => installed,
      name            => $package_name,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }

    # Compose deployment, backups and monitoring share these dependencies.
    ensure_packages(['coreutils', 'dash', 'docker-compose-plugin', 'gzip', 'util-linux'], {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    })

    # The parent class owns shared storage independently of individual projects.
    file { '/opt/docker':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0700',
    }

    # Share the management-helper directory with MySQL and the host's other management tools.
    if (!defined(File['/usr/local/lib/puppet'])) {
      file { '/usr/local/lib/puppet':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }
    }

    # Puppet execs and scheduled backups share the same controlled Compose container selection.
    file { '/usr/local/lib/puppet/docker-compose-container':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      source  => 'puppet:///modules/docker/compose_container',
      require => [File['/usr/local/lib/puppet'], Package['dash', 'docker']],
    }

    # Keep the runner available when one project is retired while others still use it.
    file { '/usr/local/lib/puppet/docker-compose-backup':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      source  => 'puppet:///modules/docker/compose_backup',
      require => File['/usr/local/lib/puppet'],
    }

    # Create service check
    if ($monitoring_enable and $basic_settings::monitoring::package != 'none') {
      # Install the check's shell, text tools, JSON parser and Docker CLI.
      $monitoring_packages = ['docker-ce-cli', 'jq', 'mawk', 'sed']

      ensure_packages($monitoring_packages, {
        'ensure'          => 'installed',
        'install_options' => ['--no-install-recommends', '--no-install-suggests'],
      })

      # Prepare package names before constructing resource dependencies.
      $monitoring_required_packages = concat(
        $monitoring_packages,
        ['coreutils', 'dash', 'docker-compose-plugin'],
      )

      # The parent owns one shared check; project definitions only register their arguments.
      basic_settings::monitoring_custom { 'docker_compose':
        source   => 'puppet:///modules/docker/check_compose',
        register => false,
        require  => Package[$monitoring_required_packages],
      }
    }
  } else {
    fail("Unsupported docker edition: ${edition}")
  }
}
