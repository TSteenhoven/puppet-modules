
define basic_settings::systemd_target(
	$description,
	$parent_targets,
	$ensure                 = present,
	$stronger_requirements  = true, 
	$allow_isolate          = false,
	$unit                   = {},
	$install                = {}
) {

	file { "/etc/systemd/system/${title}.target":
		ensure  => $ensure,
		content => template('basic_settings/systemd/target'),
		mode    => '0644',
		notify  => Exec['systemd_daemon_reload']
	}
}
