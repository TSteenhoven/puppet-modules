# @summary Writes a custom auditd rule fragment.
#
# This defined type ensures auditd and `/etc/audit/rules.d` exist, then writes
# `/etc/audit/rules.d/<order>-<title>.rules` from the shared template. It is the repository-wide helper for adding
# package, service, and configuration audit coverage without duplicating file ownership and service notification logic.
#
# @example Add a custom audit rule
#   basic_settings::security_audit { 'example':
#     rules => ['-a always,exit -F arch=b64 -F path=/etc/example.conf -F perm=wa -F key=example'],
#   }
#
# @param ensure
#   Controls whether the audit rule fragment is present or absent.
#
# @param order
#   Numeric filename prefix used to control audit rule ordering. The default is 25.
#
# @param rule_options
#   Options appended to generated suspicious-package audit rules.
#
# @param rule_suspicious_packages
#   Executable paths rendered as suspicious-package audit rules by the template.
#
# @param rules
#   Raw audit rule lines rendered into the fragment.
#
# @api public
define basic_settings::security_audit (
  Enum['present', 'absent'] $ensure                   = present,
  Integer                   $order                    = 25,
  Array                     $rule_options             = [],
  Array                     $rule_suspicious_packages = [],
  Array                     $rules                    = [],
) {
  # Check if auditd package is not defined
  if (!defined(Package['auditd'])) {
    package { 'auditd':
      ensure          => installed,
      install_options => ['--no-install-recommends', '--no-install-suggests'],
    }
  }

  # Enable auditd service
  if (!defined(Service['auditd'])) {
    service { 'auditd':
      ensure  => true,
      enable  => true,
      require => Package['auditd'],
    }
  }

  # The helper also supports callers without the full security class and owns the complete rule-fragment directory in that case.
  if (!defined(File['/etc/audit/rules.d'])) {
    file { '/etc/audit/rules.d':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      recurse => true,
      force   => true,
      purge   => true,
      mode    => '0600',
      require => Package['auditd'],
    }
  }

  # Create rule file
  file { "/etc/audit/rules.d/${order}-${title}.rules":
    ensure  => $ensure,
    content => template('basic_settings/security/custom.rules'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Service['auditd'],
    require => File['/etc/audit/rules.d'],
  }
}
