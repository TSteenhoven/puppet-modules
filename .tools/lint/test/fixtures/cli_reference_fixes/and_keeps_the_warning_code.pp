$refs = [
  File['/tmp/z'], # Keep the reason attached to this resource.
  Service['nginx'],
  File['/tmp/a'],
]
