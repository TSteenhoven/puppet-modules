$config_file_shell = stdlib::shell_escape($config_file)
# Normalize whitespace before constructing the registration command.
$server_name_correct = regsubst($server_name, '\s+', ' ', 'G')
