class example (String $argument) {
  $argument_shell = stdlib::shell_escape($argument)
  $script = "/usr/bin/printf %s ${argument_shell}"
  exec { 'demo': command => $script }
}
