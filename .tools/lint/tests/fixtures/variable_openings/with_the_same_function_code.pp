if $active {
  $config_shell = stdlib::shell_escape($config)

  # Prepare a related name and label.
  $name = regsubst($input, '\s+', ' ', 'G')
  $name_shell = stdlib::shell_escape($name)
  $label = "Check ${name}"

  # Escape the remaining check settings.
  $timeout_shell = stdlib::shell_escape(String($timeout))
  $command = "${config_shell} ${name_shell} ${timeout_shell}"
}
