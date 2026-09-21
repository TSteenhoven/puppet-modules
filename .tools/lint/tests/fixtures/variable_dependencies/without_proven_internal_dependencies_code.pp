# Escape the independent settings for the command.
$detail_shell = stdlib::shell_escape(String($detail))
$timeout_shell = stdlib::shell_escape(String($timeout))
$warning_shell = stdlib::shell_escape(String($warning))
$critical_shell = stdlib::shell_escape(String($critical))
