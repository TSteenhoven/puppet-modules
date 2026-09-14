define example::guard (String $argument, Boolean $enabled = true) {
  if $enabled {
    $argument_shell = stdlib::shell_escape($argument)
    $guard = Sensitive.new("/bin/test -e ${argument_shell}")
  } else {
    $guard = undef
  }
  exec { 'example': command => '/bin/true', unless => $guard }
}
