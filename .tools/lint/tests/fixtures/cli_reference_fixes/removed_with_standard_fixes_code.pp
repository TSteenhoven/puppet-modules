# Declare the example dependency.
notify { 'example':
  require => [
      Package["a","b"],
  ],
}
