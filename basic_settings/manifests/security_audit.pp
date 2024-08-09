
define basic_settings::security_audit(
    Optional[Enum['present','absent']]  $ensure                     = present,
    Optional[Integer]                   $order                      = 25,
    Optional[Array]                     $rule_options               = [],
    Optional[Array]                     $rule_suspicious_packages   = [],
    Optional[Array]                     $rules                      = []
) {

    /* Enable auditd service */
    if (!defined(Service['auditd'])) {
        service { 'auditd':
            ensure  => true,
            enable  => true,
            require => Package['auditd']
        }
    }

    # Create audit rule dir */
    if (!defined(File['/etc/audit/rules.d'])) {
        file { '/etc/audit/rules.d':
            ensure  => directory,
            recurse => true,
            force   => true,
            purge   => true,
            mode    => '0700'
        }
    }

    /* Create rule file */
    file { "/etc/audit/rules.d/${order}-${title}.rules":
        ensure  => $ensure,
        content => template('basic_settings/security/custom.rules'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service['auditd'],
        require => File['/etc/audit/rules.d']
    }
}
