# @summary Installs tools for an example consumer.
#
# @example Install the example
#   include example
#
# @api public
class example {
  # Install the shared backup tools.
  $backup_packages = ['alpha', 'beta']
  ensure_packages($backup_packages, { 'ensure' => 'installed' })

  # Keep non-package dependencies in their own reference list.
  $admin_require = [Exec['admin'], File['config']]

  # Prepare resource titles before constructing dependencies.
  $backup_required_packages = concat(
    $backup_packages,
    ['server'],
  )

  # Register the consumer after its prerequisites.
  notify { 'consumer':
    require => concat(Package[$backup_required_packages], $admin_require),
  }
}
