class example {
  if $parent {
    if $valid {
      notice('Valid')
    } else {
      warning('Invalid settings')
    }
  } else {
    fail('Missing parent')
  }
  notify { 'outside-validation': }
}
