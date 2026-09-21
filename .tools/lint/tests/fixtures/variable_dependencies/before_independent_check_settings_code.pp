# Normalize names for the command and its label.
$server_name_correct = regsubst($server_name ? { undef => '', default => $server_name }, '\s+', ' ', 'G')
$server_name_shell = stdlib::shell_escape($server_name_correct)
$check_friendly = "Nginx TLS ${server_name_correct}"
$detail_limit_shell = stdlib::shell_escape(String($detail_limit))
$timeout_shell = stdlib::shell_escape(String($timeout))
$validity_critical_shell = stdlib::shell_escape(String($validity_critical))
$validity_warning_shell = stdlib::shell_escape(String($validity_warning))
$command = "${server_name_shell} ${detail_limit_shell} ${timeout_shell} ${validity_critical_shell} ${validity_warning_shell}"
