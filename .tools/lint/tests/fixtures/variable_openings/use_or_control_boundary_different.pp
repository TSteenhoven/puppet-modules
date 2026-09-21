if $active {
$config_shell = stdlib::shell_escape($config)
# Format the timeout.
$timeout_label = String($timeout)
}
