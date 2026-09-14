class example (Optional[String] $content = undef, Optional[String] $source = undef) {
  if $source == undef or $content == undef {
    file { '/tmp/example': source => $source, content => $content, owner => 'root', group => 'root', mode => '0600' }
  } else { fail('Choose one input') }
}
