# @summary Requests or removes a Certbot certificate.
#
# This defined type runs Certbot for a named certificate after the `letsencrypt` class has installed shared defaults. It
# supports idempotent creation based on the certificate domain list and idempotent deletion based on the certificate
# name.
#
# @example Request an nginx certificate
#   letsencrypt::certificate { 'www.example.org':
#     domains => ['www.example.org', 'example.org'],
#   }
#
# @param domains
#   Domain names passed to Certbot with repeated `-d` arguments.
#
# @param ensure
#   Requests the certificate when `present`; deletes it when `absent`.
#
# @param plugin
#   Certbot plugin name used in the command. The default is `nginx`.
#
# @api public
define letsencrypt::certificate (
  Array                     $domains,
  Enum['present', 'absent'] $ensure  = present,
  String                    $plugin  = 'nginx',
) {
  # Require the Certbot parent before resolving plugin dependencies and issuing certificates.
  if (defined(Class['letsencrypt'])) {
    # Try to get require
    case $plugin {
      'nginx': {
        # Require the Nginx authenticator alongside Certbot and its shell helper.
        $certificate_require = [Package['certbot', 'grep', 'python3-certbot-nginx']]
      }
      default: {
        # Require Certbot and its shell helper without an Nginx authenticator.
        $certificate_require = [Package['certbot', 'grep']]
      }
    }

    # Set binary
    $cerbot_bin = '/usr/bin/certbot'

    # Escape certbot command arguments before using them in exec commands and guards.
    $cerbot_bin_shell = stdlib::shell_escape($cerbot_bin)
    $plugin_shell = stdlib::shell_escape($plugin)
    $name_shell = stdlib::shell_escape($name)

    # Run command based on ensure
    case $ensure {
      'present': {
        # Convert array to string
        $domain_sort = $domains.sort();
        $domain_list_find = join($domain_sort, ' ')

        # Escape domain arguments and grep pattern before certbot commands use them.
        $domain_args_shell = join($domain_sort.map |$domain| {
          # Escape the certificate's domain before using it in Certbot command arguments.
          $domain_shell = stdlib::shell_escape($domain)
          "-d ${domain_shell}"
        }, ' ')
        $domain_find_shell = stdlib::shell_escape("Domains: ${domain_list_find}")

        # Check if fullchain.pem and privkey.pem exists
        exec { "letsencrypt_certificate_${name}":
          command => "${cerbot_bin_shell} run --${plugin_shell} -n --cert-name ${name_shell} ${domain_args_shell}",
          unless  => "${cerbot_bin_shell} certificates -n --cert-name ${name_shell} | /usr/bin/grep ${domain_find_shell}",
          require => $certificate_require,
        }
      }
      'absent': {
        # Escape the certificate name grep pattern before checking certbot output.
        $certificate_name_find_shell = stdlib::shell_escape("Certificate Name: ${name}")

        # Delete fullchain.pem and privkey.pem
        exec { "letsencrypt_certificate_${name}":
          command => "${cerbot_bin_shell} delete --${plugin_shell} --cert-name ${name_shell}",
          onlyif  => "${cerbot_bin_shell} certificates -n --cert-name ${name_shell} | /usr/bin/grep ${certificate_name_find_shell}",
          require => $certificate_require,
        }
      }
      default: {
        fail('Unknown ensure: $ensure, must be present or absent')
      }
    }
  } else {
    fail('Class lletsencryptet is not defined, but is required for letsencrypt::certificate')
  }
}
