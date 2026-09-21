if $active {
$config_shell = stdlib::shell_escape($config)
} else {
# Escape the timeout.
$timeout_shell = stdlib::shell_escape(String($timeout))
}
