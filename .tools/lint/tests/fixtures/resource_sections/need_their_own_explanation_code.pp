if $active {
  $message = 'active'
} else {
  $message = 'inactive'
}
notify { 'state': message => $message }
