class example (Array[String] $arguments) {
  $words_shell = $arguments.map |$argument| { stdlib::shell_escape($argument) }
  $command = join(['/bin/echo', join($words_shell, ' ')], ' ')
  exec { 'demo': command => $command }
}
