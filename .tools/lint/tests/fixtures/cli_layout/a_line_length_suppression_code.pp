# Check the outer prerequisite.
if $active { # lint:ignore:140chars

  # Check the nested prerequisite.
  if $ready {
    notice('Ready')
  }
}
