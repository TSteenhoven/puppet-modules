
define basic_settings::security_audit(
    $rules = [],
    $rule_suspicious_packages = [],
    $order = 20
) {

    /* Enable auditd service */
    if (!defined(Service['auditd'])) {
        service { 'auditd':
            ensure  => true,
            enable  => true,
            require => Package['auditd']
        }
    }

    /* Create rule file */
    file { "/etc/audit/rules.d/${order}-${title}.rules":
        ensure  => $ensure,
        content => template('basic_settings/security/custom.rules'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        notify  => Service['auditd']
    }
}
