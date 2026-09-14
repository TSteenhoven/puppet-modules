$monitoring_enable = defined(Class['basic_settings::monitoring'])
$active = $ensure == present and $monitoring_enable and $basic_settings::monitoring::package != 'none'
if (!$active or ($validity_critical < $validity_warning and $config_file !~ /[\r\n\t]/)) {
  notice('Valid registration settings')
}
