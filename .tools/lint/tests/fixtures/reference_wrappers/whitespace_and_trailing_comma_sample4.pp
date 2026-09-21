notify { 'example':
  require => Package[
    'a',
    'b',
  ],
}
