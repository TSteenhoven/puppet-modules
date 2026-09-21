# Select the active state.
if $active {
  $value = 'active'
} elsif $pending {
  $value = 'pending'
} else {
  $value = 'inactive'
}
