# Prepare arguments only for the active check.
if $active {
  $config_shell = stdlib::shell_escape($config)

  # Escape the check limits.
  $timeout_shell = stdlib::shell_escape(String($timeout))
}
