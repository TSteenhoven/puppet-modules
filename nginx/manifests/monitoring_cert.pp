# @summary Registers a local Nginx TLS certificate and key check.
#
# Requires the nginx class and the File resource supplied by config_file. The normal caller is nginx::server, which
# registers separate main and redirect checks and supplies its own configuration path. This helper never includes
# monitoring classes or creates executable copies. The nginx class owns one shared root-owned 0700 check_nginx_cert
# script and its runtime package dependencies through basic_settings::monitoring_custom. This
# helper passes safely escaped server names, the configuration file and check settings as arguments.
# The script uses nginx -T with nginx::config_file and the binary default prefix, discovers paths at runtime and
# validates against self-issued roots from the Debian/Ubuntu system trust bundle. Custom service command-line overrides
# are outside this module contract. Install internal root CAs through the system trust mechanism.
# ssl_trusted_certificate is inspected separately and never supplies missing offered intermediates or trust anchors.
# Concrete DNS aliases are checked; Nginx wildcard/regex names, dynamic paths and encrypted keys are UNKNOWN. Nothing
# renews certificates, reloads Nginx or verifies a live endpoint. Root access is required under the existing agent
# sandbox; private keys remain private and certificates beneath protected home directories are unassessable.
# Automatic vhost checks follow nginx::server lifecycle, including ensure => absent and monitoring_cert => false. The
# shared concat registry removes retired registrations on every apply, including deleted declarations; no per-vhost
# executable remains to clean up. The shared script follows the nginx class monitoring state. Keep
# basic_settings::monitoring declared with package => none during backend retirement.
#
# @example Monitor an explicitly managed vhost
#   include nginx
#   nginx::server { 'app': server_name => 'app.example.org', monitoring_cert => false }
#
#   # Register the explicitly managed vhost against the shared certificate check.
#   nginx::monitoring_cert { 'app/external':
#     config_file => '/etc/nginx/conf.d/app.conf',
#     server_name => 'app.example.org',
#     require     => Nginx::Server['app'],
#   }
#
# @param config_file
#   Absolute path supplied by the owner of the target File resource; distinguishes vhosts with identical server names.
#
# @param detail_limit
#   Optional diagnostic character limit before the always-visible Interpretation section. `undef` omits -l and uses the
#   environment value or script default.
#
# @param ensure
#   `present` registers only with an active monitoring backend; `absent` removes the registration while preserving the
#   shared executable.
#
# @param interval
#   Agent execution interval in seconds. The default is 300; every active vhost check runs nginx -T once per interval.
#
# @param registration_name
#   Readable identity between check_nginx_ and _cert; undef uses the resource title. Characters other than ASCII
#   letters, digits, underscores and hyphens become underscores. Names must remain unique on the host after
#   normalization; collisions fail catalog compilation. nginx::server supplies the first main server_name followed by
#   /main or /redirect, falling back to its title when server_name is empty. This identity only labels the registration
#   and never replaces the server_name argument used for certificate validation.
#
# @param server_name
#   Actual server_name directive input, separate from the title. `undef` or empty input produces UNKNOWN without a title
#   fallback.
#
# @param timeout
#   Optional timeout override in seconds for both script and agent. `undef` omits -t and uses the script environment
#   value or default, while the agent uses monitoring_custom's default. The script reserves three seconds for
#   termination and output and kills remaining children.
#
# @param validity_critical
#   Optional critical validity threshold in days. `undef` omits -c and uses the environment value or script default. The
#   minimum remaining validity must be strictly below the threshold to trigger it. Must be below the effective warning
#   threshold; the script validates combinations with omitted values.
#
# @param validity_warning
#   Optional warning validity threshold in days. `undef` omits -w and uses the environment value or script default.
#   Remaining validity must be strictly below the threshold to trigger it. Must exceed the effective critical threshold;
#   the script validates combinations with omitted values. Expired/not-yet-valid certificates are always critical.
#
# @api public
define nginx::monitoring_cert (
  Stdlib::Absolutepath         $config_file,
  Optional[Integer[1, 100000]] $detail_limit      = undef,
  Enum['present', 'absent']    $ensure            = present,
  Integer[1]                   $interval          = 300,
  Optional[String[1]]          $registration_name = undef,
  Optional[String]             $server_name       = undef,
  Optional[Integer[5, 300]]    $timeout           = undef,
  Optional[Integer[1, 36500]]  $validity_critical = undef,
  Optional[Integer[2, 36501]]  $validity_warning  = undef,
) {
  # Require the Nginx parent that owns the shared certificate-check executable.
  if (defined(Class['nginx'])) {
    # Validate settings only for active registrations; retirement does not consume the path or thresholds.
    $active = $ensure == present and $nginx::monitoring_enable and $basic_settings::monitoring::package != 'none'
    $settings_valid = $active ? {
      true    => (($validity_critical == undef or $validity_warning == undef or $validity_critical < $validity_warning)
        and $config_file !~ /[\r\n\t]/),
      default => true,
    }
    if ($settings_valid) {
      # Build target arguments only for active registrations.
      if ($active) {
        # Nginx name-token whitespace can be normalized; literal line breaks cannot pass through an INI command value.
        $server_name_correct = regsubst($server_name ? { undef => '', default => $server_name }, '\s+', ' ', 'G')
        $server_name_shell = stdlib::shell_escape($server_name_correct)
        $check_friendly = "Nginx TLS ${server_name_correct}"

        # Escape required arguments; optional runtime defaults belong to the shared script.
        $config_file_shell = stdlib::shell_escape($config_file)

        # Omit each unset override independently, without serializing undef as an empty argument.
        $check_overrides = {
          '-l' => $detail_limit,
          '-t' => $timeout,
          '-c' => $validity_critical,
          '-w' => $validity_warning,
        }.filter |$option, $value| { $value != undef }.map |$option, $value| {
          # Escape only supplied values before appending their fixed option names.
          $value_shell = stdlib::shell_escape(String($value))
          "${option} ${value_shell}"
        }

        # Combine the target and limits into this registration's arguments.
        $check_cmd = join(concat([
          "-n ${server_name_shell} -f ${config_file_shell}",
        ], $check_overrides), ' ')

        # A File is the normal contract; standalone callers can order their owner wrapper before this helper.
        $check_require = [
          File[$config_file], Basic_settings::Monitoring_custom['nginx_cert'],
        ]
      } else {
        # Remove inactive registration without a command or certificate-file dependency.
        $check_cmd = undef
        $check_friendly = 'Nginx local TLS certificate'
        $check_require = undef
      }

      # Keep the registration identity stable when a target is enabled or retired.
      $check_ensure = $active ? { true => present, default => absent }
      $registration_name_correct = $registration_name ? { undef => $name, default => $registration_name }
      $check_id = "nginx_${regsubst($registration_name_correct, '[^A-Za-z0-9_-]', '_', 'G')}_cert"

      # Apply this target's arguments and lifecycle to its registration against the shared executable.
      basic_settings::monitoring_custom { $check_id:
        ensure        => $check_ensure,
        cmd           => $check_cmd,
        friendly      => $check_friendly,
        interval      => $interval,
        root_required => true,
        script        => 'nginx_cert',
        timeout       => $timeout,
        require       => $check_require,
      }
    } else {
      fail('nginx::monitoring_cert requires ordered positive validity thresholds and a configuration path without control characters.')
    }
  } else {
    fail('The nginx class must be included before using the nginx::monitoring_cert defined type.')
  }
}
