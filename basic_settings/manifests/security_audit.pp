
define basic_settings::security_audit(
    $ensure                     = present,
    $order                      = 25,
    $rule_options               = [],
    $rule_suspicious_packages   = [],
    $rules                      = []
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
            mode    => '0750'
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
