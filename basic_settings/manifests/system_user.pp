define basic_settings::system_user(
    $home,
    $uid,
    $gid,
    $password,
    $ensure	            = present,
    $groups	            = [],
    $bash_profile       = undef,
    $bashrc	            = undef,
    $bash_aliases	    = undef,
    $authorized_keys	= undef,
    $shell              = '/bin/bash',
    $disable_group		= false,
    $disable_home 		= false
) {

	/* Create only user group when group is disabled */
	if (!$disable_group) {
        group { $name:
            ensure		=> $ensure,
            gid			=> $gid
        }
	}

    /* Create user */
	user { $name:
		ensure		=> $ensure,
		uid			=> $uid,
		gid			=> $gid,
		groups		=> $groups,
		shell		=> $shell,
		home		=> $home,
		managehome	=> false,
		password	=> $password,
	}

	if ($ensure == present) {
		Group[$name] -> User[$name]
	} else {
		User[$name] -> Group[$name]
	}

	if (!$disable_home) {
		file { $home:
			ensure	=> $ensure ? { absent => undef, default => directory },
			mode	=> $name ? {
				root	=> '0700',
				default	=> '0755',
			},
			owner	=> $uid,
			group	=> $gid,
		}
	}

    /* Create ssh dir */
	file { "$home/.ssh":
		ensure	=> $ensure ? { absent => undef, default => directory },
		owner	=> $uid,
		group	=> $gid,
		mode	=> '0700'
	}

    /* Create authorized_keys file */
	if ($authorized_keys != undef) {
		file { "$home/.ssh/authorized_keys":
			ensure	=> $ensure ? { absent => absent, default => present },
			content	=> $authorized_keys,
			mode	=> '0644',
			owner	=> $uid,
			group	=> $gid,
		}
	}

    /* Create profile file */
	if ($bash_profile != undef) {
		file { "$home/.profile":
			ensure	=> $ensure ? { absent => absent, default => present },
			content	=> $bash_profile,
			owner	=> $uid,
			group	=> $gid,
			mode	=> '0700'
		}
	}

    /* Create bashrc file */
	if ($bashrc != undef) {
		file { "$home/.bashrc":
			ensure	=> $ensure ? { absent => absent, default => present },
			content	=> $bashrc,
			owner	=> $uid,
			group	=> $gid,
			mode	=> '0700'
		}
	}

    /* Create bash aliases file */
	if ($bash_aliases != undef) {
		file { "$home/.bash_aliases":
			ensure	=> $ensure ? { absent => absent, default => present },
			content	=> $bash_aliases,
			owner	=> $uid,
			group	=> $gid,
			mode	=> '0700'
		}
	}
}
