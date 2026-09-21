class example (
  String $user = 'example', # Must precede $listen_user because its default reads this value.
  String $listen_user = $user,
) {}
