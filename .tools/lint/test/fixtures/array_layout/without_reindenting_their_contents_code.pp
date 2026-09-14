$values = [
  'first', 'second', # Several values may share a line.
  -1,
  (2 + 3),
  {
    'key' => 'value',
  },
  call(
    'argument',
  ),
  'literal [
        string content
]',
  "${name} [
      interpolated string content
]",
  /[
        pattern content
]/,
  @(TEXT),
        heredoc content [
]
TEXT
  # Keep this comment with the last element.
  'last',
]
