class nginx(
		$run_user               = 'www-data',
		$run_group              = 'www-data',
		$keepalive_requests     = 1000,
		$keepalive_timeout      = '75s',
		$types_hash_max_size    = 2048,
		$global_directives      = [],
		$events_directives      = [],
		$http_directives        = []
	) {

	/*  Check if we have sury */
	if ($basic_settings::allow_nginx) {
		$install_options = ['-t', 'nginx']
	} else {
		$install_options = []
	}

	/* Install Nginx */
	package { 'nginx':
		ensure  => installed,
		install_options => $install_options
	}

	/* Disable service */
	service { 'nginx':
		ensure => true,
		enable => false,
		require => Package['nginx']
	}

	/* Create drop in for services target */
	basic_settings::systemd_drop_in { 'nginx_dependency':
		target_unit => "{$basic_settings::cluster_id}-services.target",
		unit        => {
			'BindsTo'   => 'nginx.service'
		},
		require => basic_settings::systemd_target["{$basic_settings::cluster_id}-services"]
	}

	/* Create log file */
	file { '/var/log/nginx':
		ensure  => directory,
		owner   => $run_user,
		require => Package['nginx']
	}

	/* Create nginx config file */
	file { '/etc/nginx/nginx.conf':
		ensure  => present,
		content => template('nginx/global.conf'),
		notify  => Service['nginx'],
		require => Package['nginx']
	}
	
	/* Create sites connfig directory */
	file { '/etc/nginx/conf.d':
		ensure  => directory,
		purge   => true,
		force   => true,
		recurse => true,
		require => Package['nginx']
	}

	/* Create snippets directory */
	file { 'nginx_snippets':
		path    => '/etc/nginx/snippets',
		ensure  => directory,
		owner   => 'root',
		group   => 'root',
		mode    => '0770',
		require => Package['nginx']
	}

	/* Create FastCGI PHP config */
	file { 'nginx_fastcgi_php_conf':
		path    => '/etc/nginx/snippets/fastcgi-php.conf',
		ensure  => file,
		source  => 'puppet:///modules/nginx/fastcgi-php.conf',
		owner   => 'root',
		group   => 'root',
		mode    => '0600',
		require => File['nginx_snippets'],
		notify  => Service['nginx']
	}

	/* Create FastCGI config */
	file { 'nginx_fastcgi_conf':
		path    => '/etc/nginx/fastcgi.conf',
		ensure  => file,
		source  => 'puppet:///modules/nginx/fastcgi.conf',
		owner   => 'root',
		group   => 'root',
		mode    => '0600',
		require => File['nginx_fastcgi_php_conf'],
		notify  => Service['nginx']
	}
}
