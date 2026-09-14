$ready = true
if $ready {
  if $valid {
    notify { 'synthetic': }
  } else {
    fail('Invalid settings')
  }
} else {
  fail('Missing prerequisite')
}
