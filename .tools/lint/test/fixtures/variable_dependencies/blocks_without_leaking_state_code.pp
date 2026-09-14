if $active {
  # Prepare the label inside this branch.
  $first = 'one'
  $second = $first
  $timeout = 30
} else {
  $timeout = 60
}
$result = $items.map |$item| {
  # Prepare the label inside this lambda.
  $first = $item
  $second = $first
  $limit = 100
  $second
}
