# @summary Installs example tools.
#
# @example Install the tools
#   include example
#
# @api public
class example {
  # Install missing command line tools.
  ensure_packages(
    [
      'alpha',
      'beta',
    ],
    {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    },
  )
}
