# @summary Installs the Docker engine package.
#
# This class installs Docker CE using the package name selected by `edition`.
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
  # Determine the correct package name based on the edition
  case $edition {
    'ce': {
      $package_name = 'docker-ce'
    }
    default: {
      fail("Unsupported docker edition: ${edition}")
    }
  }

  # Install docker
  package { 'docker':
    ensure          => installed,
    name            => $package_name,
    install_options => ['--no-install-recommends', '--no-install-suggests'],
  }
}
