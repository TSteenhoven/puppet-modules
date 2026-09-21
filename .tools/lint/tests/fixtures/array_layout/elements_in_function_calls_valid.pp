$token_reader = join([
  'set -eu; umask 077; exec >/dev/null 2>&1;',
  'CI_SERVER_TOKEN=$(cat); export CI_SERVER_TOKEN;',
  'exec gitlab-runner register "$@"',
], ' ')
