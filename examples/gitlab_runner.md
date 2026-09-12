# GitLab Runner with Docker Compose

Use [`gitlab_runner.pp`](gitlab_runner.pp) on a dedicated Debian/Ubuntu runner host or VM where `docker`, its APT source and `basic_settings::systemd` are already configured. The existing Compose wrapper manages the stack under `/opt/docker/<title>`. The [Puppet Strings](../docker/manifests/gitlab_runner.pp) describe the parameters.

## Registration

Create the runner in GitLab first and supply its runner authentication token through your protected secret provider as `Sensitive[String]`. The example's `profile::gitlab_runner::runner_token` lookup must return that type; a profile can use Hiera `lookup_options` with `convert_to: Sensitive` when its encrypted backend returns a String. Keep real tokens out of manifests, plaintext Hiera, command lines and logs.

`auto_register => true` adds one Puppet exec that runs `gitlab-runner register --non-interactive` through `docker exec` inside the running Compose container. Registration uses the configured URL and description, Docker executor, `alpine:latest` job image and `if-not-present` job pull policy. `image_tag` is a String selecting the Runner image and defaults to `latest`; Docker checks the tag. Line breaks are rejected because the value goes into a single `.env` entry.

The token is supplied through a separate root-owned `0600` file with Sensitive content, disabled diffs and disabled filebucket backups. Puppet feeds this file to `docker exec -i` through stdin; a short inline shell reads it into `CI_SERVER_TOKEN` inside the container. The `-i` option keeps stdin open for token delivery; no terminal (`-t`) is allocated. The token value appears neither in the Puppet command nor in Docker's stored container environment. Registration output is discarded. There is no registration helper executable or additional configuration format.

The legacy `--registration-token` command uses a different GitLab workflow. With a runner authentication token, configure tags, maintenance notes, untagged-job acceptance, locked status and protected access when creating or editing the runner in GitLab. Do not pass those legacy registration options to this command. See [GitLab runner registration](https://docs.gitlab.com/runner/register/) and the [supported token environment variable](https://docs.gitlab.com/runner/commands/).

Puppet starts the Compose service after preparing its files and loading its systemd unit and target binding. Registration uses [`docker::compose_exec`](../docker/manifests/compose_exec.pp) to wait for these resources, select the container and pass arguments and stdin. Keep one Puppet agent responsible for this project and avoid concurrent manual registration. See GitLab's [non-interactive registration](https://docs.gitlab.com/runner/commands/#non-interactive-registration) and Docker's [`exec` options](https://docs.docker.com/reference/cli/docker/container/exec/).

## Internal GitLab address

If ordinary DNS does not resolve your GitLab hostname to the required internal address, set `runner_ip` alongside `runner_url`. Use Docker Compose 2.24.1 or later for the `HOST:IP` form of [`extra_hosts`](https://docs.docker.com/reference/compose-file/services/#extra_hosts). Replace the documentation address below with your internal IPv4 or IPv6 address, without a subnet prefix or IPv6 brackets.

```puppet
docker::gitlab_runner { 'gitlab-runner':
  auto_register => true,
  runner_ip     => '192.0.2.50',
  runner_token  => lookup('profile::gitlab_runner::runner_token', Sensitive[String]),
  runner_url    => 'https://gitlab.example.org:8443/',
  require       => Class['docker'],
}
```

Puppet parses the URL and writes `RUNNER_URL=https://gitlab.example.org:8443/`, `RUNNER_HOST=gitlab.example.org` and `RUNNER_IP=192.0.2.50` to the existing private `.env`. The Compose service `runner` receives `extra_hosts: ["${RUNNER_HOST}:${RUNNER_IP}"]`, which also covers registration executed inside that container. Protocol, port and path are never included in the host mapping. The runner keeps the original URL and TLS verification. The existing URL policy requires HTTPS and rejects credentials, query strings and fragments.

Omitting `runner_ip`, setting it to `undef`, or using an empty string omits both mapping variables and the complete `extra_hosts` section. Removing a previously configured address restores ordinary DNS through the existing Compose service refresh. Address changes recreate the manager; pause the runner and drain jobs first as described below. Existing `config.toml` and the registration identity are preserved, so changing `runner_url` does not rewrite an existing registration: it must still match that registration's GitLab URL. Docker executor and job-container settings are unaffected; ensure jobs have their own working route and name resolution to GitLab.

## Subsequent runs and failures

Puppet's `creates` guard skips registration whenever `config/config.toml` exists. The guard only checks local file existence and has no registration side effects during `--noop`. Image changes, token rotation and container recreation do not register again while that file remains. Puppet does not manage the contents of `config.toml` or `.runner_system_id`.

After successful registration, omit `runner_token` or set it to `undef` and remove the mandatory lookup from the calling profile. Puppet removes only the bootstrap copy; the active runtime token remains in `config.toml`. An existing registration can also be used with `auto_register => false`. When automatic registration is disabled, register manually before using the runner.

The simple file guard does not parse TOML or prove that registration succeeded. An empty, partial or damaged file also prevents another attempt. After a failed or interrupted registration, pause further Puppet runs and inspect the local configuration and GitLab runner manager through a protected administrative session before resuming. A timeout may leave the registration process running inside the manager container; check that process before attempting registration again. Restore a known-good configuration and system identity together, or deliberately reconcile the registration in GitLab before removing local state. There is no recovery journal or guarantee against duplicate registration after lost storage. Never delete `config.toml` merely to force a retry.

## Security and maintenance

Use this runner for trusted projects and builds. The manager controls the host Docker daemon through its socket. New job containers receive neither that socket, the Runner configuration nor host-root mounts, and registration does not enable privileged jobs or Docker-in-Docker. Existing manually edited configuration is not checked by Puppet. Host root and Docker administrators remain within the trust boundary; `Sensitive` does not encrypt every Puppet catalog or cache.

The fixed `if-not-present` job pull policy can reuse cached private images without renewed registry authorization and does not keep mutable tags current. Restrict runner access accordingly. See [GitLab's runner security guidance](https://docs.gitlab.com/runner/security/).

Pause the runner in GitLab and drain active jobs before maintenance or removal. The manager receives `SIGQUIT` with 240 seconds of Compose grace inside the wrapper's 300-second systemd stop timeout; longer jobs can still be interrupted.

`ensure => absent` delegates to the existing Compose directory-removal behavior. It does not stop containers, remove the systemd service or unregister the runner in GitLab. Before applying it, detach the stack's systemd target binding, reload systemd and stop the service/Compose stack while its files still exist. Remove its service configuration and retire the GitLab runner separately as part of that maintenance. Back up required data first: deleting the project directory loses the bootstrap file, runtime token, system identity and project-local bind-mount data. Docker named volumes are not deleted by this directory removal.

## Validation before use

Run the [repository validation commands](../.tools/lint/README.md#code-controleren) after the documented bundle setup. The central `bundle exec rake test` command tests repository tools; it does not validate this runner's behavior. Validate catalogs and rendered configuration with temporary synthetic checks outside the repository, including URL/address validation, mapping variants, registration arguments, dependency order, private files and preservation of other Compose stacks.

On an isolated Linux host, validate the Compose file with `docker compose config --quiet`, register a disposable test runner and execute a job that checks out a repository and uploads an artifact. Repeat Puppet and `--noop`, remove the bootstrap token, recreate the manager and reboot. Verify job containers have no host-socket or Runner-config mounts and are not privileged. Test two stacks and manually retire one while the other continues running. Record unavailable checks separately; a successful local command is not proof that CI jobs work.
