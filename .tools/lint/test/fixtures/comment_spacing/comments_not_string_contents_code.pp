$message = 'First line.
# This is literal text.
Last line.'
$other = "A # sign in a string" # Trailing explanation.
$payload = @(TEXT)
  }
  # This is heredoc content.
  notify { 'literal': }
  | TEXT
