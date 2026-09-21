class example (String $argument) {
  if $argument == 'example' {
    $argument_shell = stdlib::shell_escape($argument)
  } else {
    $argument_shell = $argument
  }
  exec { 'demo': command => "/bin/echo ${argument_shell}" }
}
