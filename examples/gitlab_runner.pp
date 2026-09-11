# Use a dedicated runner host with the existing Docker APT source and systemd target configuration.
# Read examples/gitlab_runner.md for registration, Hiera requirements, recovery and maintenance.
# This profile key must return Sensitive[String] from your protected secret source.
docker::gitlab_runner { 'gitlab-runner':
  auto_register      => true,
  image_tag          => 'latest',
  runner_description => 'docker-runner',
  runner_token       => lookup('profile::gitlab_runner::runner_token', Sensitive[String]),
  runner_url         => 'https://gitlab.com/',
  require            => Class['docker'],
}
