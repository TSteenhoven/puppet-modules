# @summary Registers a local Nginx TLS certificate and key check.
#
# lint:ignore:140chars
# Requires the nginx class and the File resource supplied by config_file. The normal caller is nginx::server, which registers separate main and redirect checks and supplies its own configuration path. This helper never includes monitoring classes or creates executable copies. The nginx class owns one shared root-owned 0700 check_nginx_cert script and its OpenSSL, CA certificate and coreutils dependencies through basic_settings::monitoring_custom. This helper passes safely escaped server names, the configuration file and check settings as arguments. A SHA256 of the complete title gives each registration a stable identity without lossy name normalization.
# The script uses nginx -T with nginx::config_file and the binary default prefix, discovers paths at runtime and validates against self-issued roots from the Debian/Ubuntu system trust bundle. Custom service command-line overrides are outside this module contract. Install internal root CAs through the system trust mechanism. ssl_trusted_certificate is inspected separately and never supplies missing offered intermediates or trust anchors. Concrete DNS aliases are checked; Nginx wildcard/regex names, dynamic paths and encrypted keys are UNKNOWN. Nothing renews certificates, reloads Nginx or verifies a live endpoint. Root access is required under the existing agent sandbox; private keys remain private and certificates beneath protected home directories are unassessable.
# Automatic vhost checks follow nginx::server lifecycle, including ensure => absent and monitoring_cert => false. The shared concat registry removes retired registrations on every apply, including deleted declarations; no per-vhost executable remains to clean up. The shared script follows the nginx class monitoring state. Keep basic_settings::monitoring declared with package => none during backend retirement.
# lint:endignore
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
#   Diagnostic character limit before the always-visible Interpretation section. The default is 6000.
#
# @param ensure
#   `present` registers only with an active monitoring backend; `absent` removes the registration while preserving the shared executable.
#
# @param interval
#   Agent execution interval in seconds. The default is 300; every active vhost check runs nginx -T once per interval.
#
# @param server_name
#   Actual server_name directive input, separate from the title. `undef` or empty input produces UNKNOWN without a title fallback.
#
# @param timeout
#   Agent timeout in seconds, default 30. The script reserves three seconds for termination and output and kills remaining children.
#
# @param validity_critical
#   Critical when the minimum remaining validity is strictly less than this many days, default 14. Must be below validity_warning.
#
# @param validity_warning
# lint:ignore:140chars
#   Warning when remaining validity is strictly less than this many days, default 30. Expired/not-yet-valid certificates are always critical.
# lint:endignore
#
# @api public
define nginx::monitoring_cert (
  Stdlib::Absolutepath      $config_file,
  Integer[1, 100000]        $detail_limit      = 6000,
  Enum['present', 'absent'] $ensure            = present,
  Integer[1]                $interval          = 300,
  Optional[String]          $server_name       = undef,
  Integer[5, 300]           $timeout           = 30,
  Integer[1, 36500]         $validity_critical = 14,
  Integer[2, 36501]         $validity_warning  = 30,
) {
  # Require the Nginx parent that owns the shared certificate-check executable.
  if (defined(Class['nginx'])) {
    # Validate settings only for active registrations; retirement does not consume the path or thresholds.
    $active = $ensure == present and defined(Class['basic_settings::monitoring']) and $basic_settings::monitoring::package != 'none'
    $settings_valid = $active ? {
      true    => ($validity_critical < $validity_warning and $config_file !~ /[\r\n\t]/),
      default => true,
    }
    if ($settings_valid) {
      # Build target arguments only for active registrations.
      if ($active) {
        # Nginx name-token whitespace can be normalized; literal line breaks cannot pass through an INI command value.
        $server_name_correct = regsubst($server_name ? { undef => '', default => $server_name }, '\s+', ' ', 'G')
        $server_name_shell = stdlib::shell_escape($server_name_correct)
        $check_friendly = "Nginx TLS ${server_name_correct}"

        # Escape the configuration path and numeric limits before passing them to the shared certificate check.
        $config_file_shell = stdlib::shell_escape($config_file)
        $detail_limit_shell = stdlib::shell_escape(String($detail_limit))
        $timeout_shell = stdlib::shell_escape(String($timeout))
        $validity_critical_shell = stdlib::shell_escape(String($validity_critical))
        $validity_warning_shell = stdlib::shell_escape(String($validity_warning))

        # Combine the target and limits into this registration's arguments.
        $check_cmd = join([
            "-n ${server_name_shell} -f ${config_file_shell}",
            "-l ${detail_limit_shell} -t ${timeout_shell}",
            "-c ${validity_critical_shell} -w ${validity_warning_shell}",
        ], ' ')

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
      $check_id = "nginx_cert_${stdlib::sha256($name)}"
      $check_ensure = $active ? { true => present, default => absent }

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
