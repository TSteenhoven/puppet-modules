define example (String $engine) {
  $alias = $engine
  if $engine == 'synthetic_backend' {
    basic_settings::monitoring_custom { $name: package => $alias }
  }
}
