class mysql (
        Optional[String]    $automysqlbackup_backupdir  = '/var/lib/automysqlbackup',
        Optional[Integer]   $nice_level                 = 12,
        Optional[String]    $package_name               = 'mysql',
        Optional[Float]     $package_version            = 8.0,
        Optional[String]    $root_password              = '',
        Optional[Hash]      $settings                   = {}
    ) {

    /* Use systemd settings */
    if (defined(Class['basic_settings::message'])) {
        $automysqlbackup_host_friendly = $basic_settings::message::server_fdqn
        $automysqlbackup_mail_address = $basic_settings::message::mail_to
    } else {
        $automysqlbackup_host_friendly = $fdqn
        $automysqlbackup_mail_address = 'root'
    }

    /* Set mysqld default values */
    $default_values = {
        'innodb_buffer_pool_size' => '256M',
        'innodb_flush_method'     => 1, # O_DSYNC
        'innodb_redo_log_capacity'=> '200M',
        'join_buffer_size'        => '2M',
        'max_allowed_packet'      => '128M',
        'max_connections'         => 1000,
        'read_buffer_size'        => '2M',
        'read_rnd_buffer_size'    => '2M',
        'sort_buffer_size'        => '2M',
        'table_open_cache'        => 512,
        'thread_cache_size'       => 16,
        'thread_stack'            => '2M'
    }

    # Merge default settings with user settings
    $mysqld_default = stdlib::merge($default_values, $settings)

    /* Basic variable */
    $script_dir = '/usr/local/lib/puppet-mysql'
    $script_path = "${script_dir}/grant.sh"

    /* Get version */
    if (defined(Class['basic_settings::package_mysql'])) {
        $version = $basic_settings::package_mysql::version
    } else {
        $version = $package_version
    }

    /* Do only the following steps when package name is mysql */
    if ($package_name == 'mysql') {
        /* Default file is different than normal install */
        $defaults_file = '/etc/mysql/mysql.conf.d/mysqld.cnf'

        /* Create list of packages that is suspicious */
        $suspicious_packages = ['/usr/bin/mysql']

        /* Install MySQL server */
        package { 'mysql-server':
            ensure => present
        }

        /* Setup audit rules */
        if (defined(Package['auditd'])) {
            basic_settings::security_audit { 'mysql':
                rule_suspicious_packages    => $suspicious_packages,
                rule_options                => ['-F auid!=unset']
            }
        }

        /* Enable hugepages */
        if (defined(Class['basic_settings']) and $basic_settings::kernel_hugepages > 0) {
            exec { 'mysql_hugetlb':
                unless => '/bin/getent group hugetlb | /bin/cut -d: -f4 | /bin/grep -q mysql',
                command => '/usr/sbin/usermod -a -G hugetlb mysql',
                require => [Group['hugetlb'], Package['mysql-server']]
            }
        }

        if (defined(Package['systemd'])) {
            /* Disable MySQL server service */
            service { 'mysql':
                ensure  => undef,
                enable  => false,
                require => Package['mysql-server']
            }

            /* Reload systemd deamon */
            exec { 'mysql_systemd_daemon_reload':
                command     => '/usr/bin/systemctl daemon-reload',
                refreshonly => true,
                require     => Package['systemd']
            }

            /* Create drop in for PHP FPM service */
            if (defined(Class['php8::fpm'])) {
                basic_settings::systemd_drop_in { "php8_${$php8::minor_version}_mysql_dependency":
                    target_unit     => "php8.${$php8::minor_version}-fpm.service",
                    unit            => {
                        'After'     => 'mysql.service',
                        'BindsTo'   => 'mysql.service'
                    },
                    daemon_reload   => 'mysql_systemd_daemon_reload',
                    require         => Class['php8::fpm']
                }
            } elsif (defined(Class['basic_settings'])) {
                /* Create drop in for services target */
                basic_settings::systemd_drop_in { 'mysql_dependency':
                    target_unit     => "${basic_settings::cluster_id}-services.target",
                    unit            => {
                        'BindsTo'   => 'mysql.service'
                    },
                    daemon_reload   => 'mysql_systemd_daemon_reload',
                    require         => Basic_settings::Systemd_target["${basic_settings::cluster_id}-services"]
                }
            }

            /* Get unit */
            if (defined(Class['basic_settings::message'])) {
                $unit = {
                    'OnFailure' => 'notify-failed@%i.service'
                }
            } else {
                $unit = {}
            }

            /* Create drop in for nginx service */
            basic_settings::systemd_drop_in { 'mysql_settings':
                target_unit     => 'mysql.service',
                unit            => $unit,
                service         => {
                    'LimitMEMLOCK'  => 'infinity',
                    'Nice'          => "-${nice_level}"
                },
                daemon_reload   => 'mysql_systemd_daemon_reload',
                require         => Package['mysql-server']
            }

            /* Create drop in for puppet service */
            basic_settings::systemd_drop_in { 'puppet_mysql_dependency':
                target_unit     => 'puppet.service',
                unit            => {
                    'Wants' => 'mysql.service'
                },
                daemon_reload   => 'mysql_systemd_daemon_reload',
                require         => Package['mysql-server']
            }
        }

        /* Check if logrotate package exists */
        if (defined(Package['logrotate'])) {
            basic_settings::io_logrotate { 'mysql-server':
                path            => "/var/log/mysql.log\n/var/log/mysql/*log",
                frequency       => 'daily',
                create_user     => 'mysql',
                rotate_post     => join([
                    'test -x /usr/bin/mysqladmin || exit 0',
                    'MYADMIN="/usr/bin/mysqladmin --defaults-file=/etc/mysql/debian.cnf"',
                    'if [ -z "`$MYADMIN ping 2>/dev/null`" ]; then',
                        "\tif killall -q -s0 -umysql mysqld; then",
                            "\t\texit 1",
                        "\tfi",
                    'else',
                        "\t\$MYADMIN flush-logs",
                    'fi'
                ], "\n\t")
            }
        }
    } else {
        /* Default file for normal install */
        $defaults_file = '/etc/mysql/debian.cnf'
        $suspicious_packages = undef
    }

    /* Install package for automysqlbackup */
    if (!defined(Package['pigz'])) {
        package { 'pigz':
            ensure  => installed
        }
    }

    /* Install package for automysqlbackup */
    if (!defined(Package['pbzip2'])) {
        package { 'pbzip2':
            ensure  => installed
        }
    }

    /* Create script dir */
    file { $script_dir:
        ensure  => directory,
        owner   => 'root',
        group   => 'root'
    }

    /* Create script */
    file { $script_path:
        ensure  => file,
        content => template('mysql/grant.sh'), # Keep this file below version and defaults_file variable
        owner   => 'root',
        group   => 'root',
        mode    => '0700'
    }

    /* Set config file */
    file { '/etc/default/automysqlbackup.conf':
        ensure  => file,
        content => template('mysql/automysqlbackup.config'),
        owner   => 'root',
        group   => 'root',
        mode    => '0600', # Only root
    }

    /* Create automysqlbackup script */
    file { '/usr/local/sbin/automysqlbackup':
        ensure  => file,
        source  => 'puppet:///modules/mysql/automysqlbackup',
        owner   => 'root',
        group   => 'root',
        mode    => '0700', # Only root
    }

    if (defined(Package['systemd'])) {
        /* Create systemd service */
        basic_settings::systemd_service { 'automysqlbackup':
            description => 'Automysqlbackup service',
            service     => {
                'Type'              => 'oneshot',
                'User'              => 'root',
                'ExecStart'         => '/usr/local/sbin/automysqlbackup',
                'Nice'              => '19',
                'PrivateDevices'    => 'true',
                'PrivateTmp'        => 'true',
                'ProtectHome'       => 'true',
                'ProtectSystem'     => 'full'
            },
            unit            => {
                'After'     => "${package_name}.service",
                'BindsTo'   => "${package_name}.service"
            },
            daemon_reload   => 'mysql_systemd_daemon_reload',
        }

        /* Create systemd timer */
        basic_settings::systemd_timer { 'automysqlbackup':
            description     => 'Automysqlbackup timer',
            timer       => {
                'OnCalendar' => '*-*-* 5:00'
            },
            daemon_reload   => 'mysql_systemd_daemon_reload',
        }
    }

    /* Create mysql cnf */
    file { 'mysql_cnf':
        path        => '/etc/mysql/mysql.cnf',
        owner       => 'mysql',
        group       => 'mysql',
        mode        => '0600',
        content     => template('mysql/mysql.cnf')
    }

    # Actual root user
    if ($root_password != '') {
        /* Create mysql user */
        mysql::user { 'root':
            username    => 'root',
            hostname    => 'localhost',
            password    => $root_password,
            ensure      => present
        }

        /* Create debian cnf */
        file { 'mysql_debian_cnf':
            path        => $defaults_file,
            content     => template('mysql/debian.cnf'),
            owner       => 'mysql',
            group       => 'mysql',
            mode        => '0600', # Only readably for user mysql
            require     => Mysql::User['root']
        }

        /* Set mysql grant for user root */
        mysql::grant { 'root_privileges':
            username        => 'root',
            hostname        => 'localhost',
            grant_option    => true,
            ensure          => present,
            require         => File['mysql_debian_cnf']
        }
    }
}
