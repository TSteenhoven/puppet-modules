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
  # Install the package only for the supported Docker edition.
  if ($edition == 'ce') {
    # Resolve the Docker CE package name for the shared package resource.
    $package_name = 'docker-ce'

    # Install Docker from the separately managed repository.
    package { 'docker':
      ensure          => installed,
      name            => $package_name,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  } else {
    fail("Unsupported docker edition: ${edition}")
  }
}
