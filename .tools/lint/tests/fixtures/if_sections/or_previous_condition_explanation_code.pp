# Check the outer prerequisite.
if $outer {
  if $inner { notice('Nested') }
} else {
  if $fallback { notice('Fallback') }
}
if $other { notice('Other') }
