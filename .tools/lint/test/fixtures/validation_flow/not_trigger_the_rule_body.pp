# warning('Only a comment')
$text = 'fail("Only text")'
$content = @(CONTENT)
warning('Only heredoc content')
CONTENT
example::warning('A different function')
example::fail('A different function')
