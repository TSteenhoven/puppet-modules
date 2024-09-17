define basic_settings::login_user (
  String                              $home,
  Integer                             $uid,
  Integer                             $gid,
  Sensitive[String]                   $password,
  Optional[Array]                     $authorized_keys    = undef,
  Optional[String]                    $bashrc             = undef,
  Optional[String]                    $bash_aliases       = undef,
  Optional[String]                    $bash_profile       = undef,
  Boolean                             $disable_group      = false,
  Enum['present','absent']            $ensure             = present,
  Array                               $groups             = [],
  Boolean                             $home_enable        = true,
  Boolean                             $home_force         = false,
  Boolean                             $home_purge         = false,
  Boolean                             $home_recurse       = false,
  Optional[String]                    $home_source        = undef,
  Optional[Integer]                   $password_max_age   = undef,
  Optional[String]                    $private_key        = undef,
  String                              $shell              = '/bin/bash'
) {
  # Set variables
  $environment = $basic_settings::login::environment
  $hostname = $basic_settings::login::hostname

  # Set authorized keys state
  if ($authorized_keys != undef) {
    $authorized_keys_purge = false
    if (empty($authorized_keys)) {
      $authorized_keys_empty = true
    } else {
      $authorized_keys_empty = false
    }
  } else {
    $authorized_keys_purge = true
    $authorized_keys_empty = true
  }

  # Get password max age
  if ($authorized_keys_empty) {
    if ($password_max_age == undef) {
      if ($password == '!!') {
        $password_max_age_correct = -1
      } else {
        $password_max_age_correct = 365
      }
    } else {
      $password_max_age_correct = $password_max_age
    }
  } elsif ($password_max_age == undef) {
    $password_max_age_correct = -1
  } else {
    $password_max_age_correct = $password_max_age
  }

  # Create only user group when group is disabled
  if (!$disable_group) {
    group { $name:
      ensure => $ensure,
      gid    => $gid,
    }
  }

  # Create user
  user { $name:
    ensure             => $ensure,
    uid                => $uid,
    gid                => $gid,
    groups             => $groups,
    shell              => $shell,
    home               => $home,
    managehome         => false,
    password           => $password,
    password_max_age   => $password_max_age_correct,
    password_warn_days => 31,
    purge_ssh_keys     => $authorized_keys_purge,
  }

  if ($ensure == present) {
    Group[$name] -> User[$name]
  } else {
    User[$name] -> Group[$name]
  }

  if ($home_enable) {
    # Make home dir
    if ($home_source != undef) {
      file { $home:
        ensure  => $ensure ? { 'absent' => undef, default => directory },
        owner   => $uid,
        group   => $gid,
        force   => $home_force,
        purge   => $home_purge,
        recurse => $home_recurse,
        source  => $home_source,
        mode    => '0700',
      }
    } else {
      file { $home:
        ensure  => $ensure ? { 'absent' => undef, default => directory },
        owner   => $uid,
        group   => $gid,
        force   => $home_force,
        purge   => $home_purge,
        recurse => $home_recurse,
        mode    => '0700',
      }
    }

    # Create ssh dir
    file { "${home}/.ssh":
      ensure  => $ensure ? { 'absent' => undef, default => directory },
      owner   => $uid,
      group   => $gid,
      mode    => '0700',
      require => File[$home],
    }

    # Create authorized_keys file
    if ($authorized_keys != undef) {
      file { "${home}/.ssh/authorized_keys":
        ensure  => $ensure ? { 'absent' => 'absent', default => present },
        content => Sensitive.new(join($authorized_keys, "\n")),
        mode    => '0600',
        owner   => $uid,
        group   => $gid,
        require => File[$home],
      }
    }

    # Create private key file
    if ($private_key != undef) {
      file { "${home}/.ssh/private.key":
        ensure  => $ensure ? { 'absent' => 'absent', default => present },
        source  => Sensitive.new($private_key),
        mode    => '0600',
        owner   => $uid,
        group   => $gid,
        require => File[$home],
      }
    }

    # Create profile file
    if ($bash_profile != undef) {
      if ($bash_profile == 'default') {
        $bash_profile_correct = template('basic_settings/login/bash/profile')
      } else {
        $bash_profile_correct = $bash_profile
      }
      file { "${home}/.profile":
        ensure  => $ensure ? { 'absent' => 'absent', default => present },
        content => $bash_profile_correct,
        owner   => $uid,
        group   => $gid,
        mode    => '0700',
        require => File[$home],
      }
    }

    # Create bashrc file
    if ($bashrc != undef) {
      if ($bashrc == 'default') {
        $bash_rc_correct = template('basic_settings/login/bash/rc')
      } else {
        $bash_rc_correct = $bashrc
      }
      file { "${home}/.bashrc":
        ensure  => $ensure ? { 'absent' => 'absent', default => present },
        content => $bash_rc_correct,
        owner   => $uid,
        group   => $gid,
        mode    => '0700',
        require => File[$home],
      }
    }

    # Create bash aliases file
    if ($bash_aliases != undef) {
      if ($bash_aliases == 'default') {
        $bash_aliases_correct = template('basic_settings/login/bash/aliases')
      } else {
        $bash_aliases_correct = $bash_aliases
      }
      file { "${home}/.bash_aliases":
        ensure  => $ensure ? { 'absent' => 'absent', default => present },
        content => $bash_aliases_correct,
        owner   => $uid,
        group   => $gid,
        mode    => '0700',
        require => File[$home],
      }
    }

    # Create audit rules
    if ($ensure and defined(Package['auditd'])) {
      basic_settings::security_audit { "${name}-ssh":
        rules => [
          "-a always,exit -F arch=b32 -F path=${home}/.ssh -F perm=r -F auid!=unset -F key=ssh",
          "-a always,exit -F arch=b64 -F path=${home}/.ssh -F perm=r -F auid!=unset -F key=ssh",
          "-a always,exit -F arch=b32 -F path=${home}/.ssh -F perm=wa -F key=ssh",
          "-a always,exit -F arch=b64 -F path=${home}/.ssh -F perm=wa -F key=ssh",
        ],
      }
    }
  }
}
