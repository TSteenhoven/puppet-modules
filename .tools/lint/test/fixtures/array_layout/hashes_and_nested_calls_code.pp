class example (
  Array[String] $defaults = [
    'default',
  ],
) {
  $nested = wrap(join([
    [
      'nested',
    ],
    { 'key' => [
      'value',
    ] },
  ], ' '))
  notify { 'example':
    message => join(
      [
        'message',
      ],
      ' ',
    ),
  }
}
