if $absent {
  $content = undef
  $dependencies = undef
} else {
  $content = template('example/check')
  $dependencies = [Package['example']]
  $owner = 'root'
  $mode = '0700'
}
