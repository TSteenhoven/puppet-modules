# @summary Installs example tools.
#
# @example Install the tools
#   include example
#
# @api public
class example {
  # Install missing command line tools.
  if (!defined(Package["alpha"])) {
    package { "alpha":
      ensure          => installed,
      install_options => ["--no-install-recommends","--no-install-suggests"],
    }
  }

  if (!defined(Package["beta"])) {
    package { "beta":
      ensure          => installed,
      install_options => ["--no-install-recommends","--no-install-suggests"],
    }
  }
}
