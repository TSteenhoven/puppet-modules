$enabled = true
# Keep the synthetic notification conditional.
if $enabled {
  notify { 'first': }
}
notify { 'second': }
