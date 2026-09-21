# Prepare the first group.
$first = 'one'
$second = $first
$third = "${second} label"
$timeout = 30
$limit = 60
$limit_shell = stdlib::shell_escape(String($limit))
$owner = 'root'
$group = 'root'
