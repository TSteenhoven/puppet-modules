class example (Optional[String] $content = undef, Optional[String] $source = undef) {
  if $source == undef { $resolved = $content } else { $resolved = undef }
  file { '/tmp/example': source => $source, content => $resolved, owner => 'root', group => 'root', mode => '0600' }
}
