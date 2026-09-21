if $valid {
  notice('Valid')
} else {
  $keys = join($invalid_keys, ', ')
  $message = "Invalid keys: ${keys}"
  warning($message)
  fail('Cannot proceed')
}
