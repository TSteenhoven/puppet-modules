class basic_settings::puppet(
    $server_enable  = false,
    $server_package = 'puppetserver',
    $server_dir     = 'puppetserver'
) {

    /* Remove unnecessary packages */
    package { 'cloud-init':
        ensure  => purged
    }

    /* Disable service */
    service { 'puppet':
        ensure  => undef,
        enable  => false
    }

    /* Create drop in for services target */
    if (defined(Class['basic_settings'])) {
        basic_settings::systemd_drop_in { 'puppet_dependency':
            target_unit     => "${basic_settings::cluster_id}-system.target",
            unit            => {
                'Wants'   => 'puppet.service'
            },
            require         => Basic_settings::Systemd_target["${basic_settings::cluster_id}-system"]
        }
    }

    /* Create drop in for puppet service */
    if (defined(Package['systemd'])) {
        basic_settings::systemd_drop_in { 'puppet_settings':
            target_unit     => 'puppet.service',
            unit            => {
                'OnFailure' => 'notify-failed@%i.service'
            },
            service         => {
                'Nice'          => 19,
                'LimitNOFILE'   => 10000
            }
        }
    }

    /* Do only the next steps when we are puppet server */
    if ($server_enable) {
        /* Disable service */
        service {  "${server_package}":
            ensure  => undef,
            enable  => false
        }

        /* Create drop in for services target */
        if (defined(Class['basic_settings'])) {
            basic_settings::systemd_drop_in { 'puppetserver_dependency':
                target_unit     => "${basic_settings::cluster_id}-system.target",
                unit            => {
                    'Wants'   => "${server_package}.service"
                },
                require         => Basic_settings::Systemd_target["${basic_settings::cluster_id}-system"]
            }
        }

        /* Create log dir */
        file { 'puppet_reports':
            ensure  => directory,
            path    => "/var/log/${server_dir}/reports",
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644'
        }

        /* Create symlink */
        file { "/var/lib/${server_dir}/reports":
            ensure => 'link',
            target => "/var/log/${server_dir}/reports",
            require => File['puppet_reports']
        }

        if (defined(Package['systemd'])) {
            /* Create drop in for puppet server service */
            basic_settings::systemd_drop_in { 'puppetserver_settings':
                target_unit     => "${server_package}.service",
                unit            => {
                    'OnFailure' => 'notify-failed@%i.service'
                },
                service         => {
                    'Nice'          => '-8',
                }
            }

            /* Create systemd puppet server clean reports service */
            basic_settings::systemd_service { 'puppetserver-clean-reports':
                description => 'Clean puppetserver reports service',
                service     => {
                    'Type'      => 'oneshot',
                    'User'      => 'puppet',
                    'ExecStart' => "/usr/bin/find /var/lib/${server_dir}/reports -type f -name '*.yaml' -ctime +1 -delete",
                    'Nice'      => '19'
                },
            }

            /* Create systemd puppet server clean reports timer */
            basic_settings::systemd_timer { 'puppetserver-clean-reports':
                description => 'Clean puppetserver reports timer',
                timer       => {
                    'OnCalendar' => '*-*-* 10:00'
                }
            }

            /* Create drop in for puppet service */
            basic_settings::systemd_drop_in { 'puppet_puppetserver_dependency':
                target_unit     => 'puppet.service',
                unit         => {
                    'After'     => "${server_package}.service",
                    'BindsTo'   => "${server_package}.service"
                }
            }
        }

        /* Setup audit rules */
        if (defined(Package['auditd'])) {
            basic_settings::security_audit { 'puppet':
                rules => [
                    '-a always,exit -F arch=b32 -F path=/etc/puppet/ssl -F perm=wa -F key=puppet_ssl',
                    '-a always,exit -F arch=b64 -F path=/etc/puppet/ssl -F perm=wa -F key=puppet_ssl',
                    '-a always,exit -F arch=b32 -F path=/etc/puppet/code -F perm=r -F auid!=unset -F key=puppet_code',
                    '-a always,exit -F arch=b64 -F path=/etc/puppet/code -F perm=r -F auid!=unset -F key=puppet_code',
                    '-a always,exit -F arch=b32 -F path=/etc/puppet/code -F perm=wa -F key=puppet_code',
                    '-a always,exit -F arch=b64 -F path=/etc/puppet/code -F perm=wa -F key=puppet_code'
                ]
            }
        }
    } elsif (defined(Package['auditd'])) {
        basic_settings::security_audit { 'puppet':
            rules => [
                '-a always,exit -F arch=b32 -F path=/etc/puppet/ssl -F perm=wa -F key=puppet_ssl',
                '-a always,exit -F arch=b64 -F path=/etc/puppet/ssl -F perm=wa -F key=puppet_ssl'
            ]
        }
    }
}
