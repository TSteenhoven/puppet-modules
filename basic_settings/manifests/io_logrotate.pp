define basic_settings::io_logrotate(
    String                              $path,
    Enum['daily','weekly', 'monthly']   $handle,
    Optional[Boolean]                   $compress       = true,
    Optional[Boolean]                   $compress_delay = false,
    Optional[String]                    $create_group   = 'root',
    Optional[String]                    $create_mode    = '600',
    Optional[String]                    $create_user    = undef,
    Optional[Enum['present','absent']]  $ensure         = present,
    Optional[Integer]                   $rotate         = undef,
    Optional[String]                    $rotate_post    = undef,
    Optional[Boolean]                   $skip_empty     = true,
    Optional[Boolean]                   $skip_missing   = true,
) {

    /* Check if this dir is not already managed by puppet */
    if (!defined(File['/etc/logrotate.d'])) {
        file { '/etc/logrotate.d':
            ensure  => directory,
            owner   => 'root',
            group   => 'root',
            mode    => '0700',
            require => Package['logrotate']
        }
    }

    /* Get rotate */
    if ($rotate == undef) {
        if (defined(Class['basic_settings::io'])) {
            $rotate_correct = $basic_settings::io::log_rotate
        } else {
            $rotate_correct = 12
        }
    } else {
        $rotate_correct = $rotate
    }

    /* Check if shared scripts is needed */
    if ($create_user != undef and $path =~ '.*') {
        $shared_scripts = true
    } else {
        $hared_scripts = false
    }

    /* Create configuration */
    file { "/etc/logrotate.d/${title}.conf":
        ensure  => $ensure,
        content => template('basic_settings/io/logrotate'),
        mode    => '0600',
        require => Package['logrotate']
    }
}
