# Select the appropriate handling for the current state.
if $active {
  notice('Unavailable')
} else {
  # Prepare the fallback values used by the alternative path.
  $first = 1
  $second = 2
}
