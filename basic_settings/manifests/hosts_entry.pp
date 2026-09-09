# @summary Adds one managed host record to `/etc/hosts`.
#
# This defined type appends a single idempotent concat fragment to the hosts file owned by `basic_settings::hosts`.
# lint:ignore:140chars
# The fragment title is based on the IP address and host name so duplicate records surface as duplicate Puppet resources instead of producing repeated lines in `/etc/hosts`.
# lint:endignore
#
# @example Add the Puppet server to `/etc/hosts`
#   basic_settings::hosts_entry { 'puppet':
#     ip       => '10.200.3.69',
#     hostname => 'puppet',
#   }
#
# @param hostname
#   Hostname or fully qualified domain name written after the IP address.
#
# @param ip
#   IPv4 or IPv6 address written for the host record.
#
# @param comment
#   Comment written above the host record. `undef` uses the resource title.
#
# @param ensure
#   Controls whether the concat fragment is emitted.
#
# @param order
#   Concat fragment order. The default places entries after the standard localhost and IPv6 fragments.
#
# @api public
define basic_settings::hosts_entry (
  String                    $hostname,
  String                    $ip,
  Optional[String[1]]       $comment  = undef,
  Enum['present', 'absent'] $ensure   = present,
  String[1]                 $order    = '50',
) {
  if (defined(Class['basic_settings::hosts'])) {
    $hosts_require = Class['basic_settings::hosts']
    $hosts_fail_text = undef
  } else {
    $hosts_fail_text = 'The basic_settings::hosts class must be included directly, or through basic_settings::network with hosts_enable => true, before using the basic_settings::hosts_entry defined type.' # lint:ignore:140chars
  }

  if ($hosts_fail_text == undef) {
    if ($ensure == present) {
      # Validate the String inputs at the output boundary so empty values cannot create malformed hosts entries.
      if ($ip != '' and $ip !~ /\s/ and $hostname != '' and $hostname !~ /\s/) {
        # Use the resource title as the operator-facing comment unless a clearer label is provided.
        if ($comment == undef) {
          $comment_correct = $name
        } else {
          $comment_correct = $comment
        }

        # Keep comments single-line so one entry cannot inject additional host records.
        if ($comment_correct !~ /[\r\n]/) {
          concat::fragment { "hosts_entry_${ip}_${hostname}":
            target  => '/etc/hosts',
            content => "# ${comment_correct}\n${ip} ${hostname}\n",
            order   => $order,
            require => $hosts_require,
          }
        } else {
          fail("basic_settings::hosts_entry[${name}] comment must not contain line breaks.")
        }
      } else {
        fail("basic_settings::hosts_entry[${name}] ip and hostname must be non-empty single tokens.")
      }
    }
  } else {
    fail($hosts_fail_text)
  }
}
