# @summary Adds a user to the managed cron allow list.
#
# This defined type creates `/etc/cron.allow` through concat when needed and inserts one fragment for the resource
# title. It is useful when cron access is intentionally limited to explicit accounts.
#
# @example Allow a service account to use cron
#   basic_settings::login_cron { 'deploy':
#     user => 'deploy',
#   }
#
# @param user
#   User account that should be allowed to run cron jobs. The current template uses the resource title as the emitted
#   username.
#
# @param order
#   Concat fragment order for the user entry. The default is `10`.
#
# @api public
define basic_settings::login_cron (
  String $user,
  String $order = '10',
) {
  # Create the shared cron allow-list once before adding account fragments.
  if (!defined(Concat['/etc/cron.allow'])) {
    concat { '/etc/cron.allow':
      owner => 'root',
      group => 'root',
      mode  => '0600',
    }
  }

  # Create fragment for each user
  concat::fragment { "cron_allow_${name}":
    target  => '/etc/cron.allow',
    content => "${name}\n",
    order   => $order,
  }
}
