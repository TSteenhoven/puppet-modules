# @summary Manages `/etc/hosts` from deterministic concat fragments.
#
# This class owns `/etc/hosts`, writes the standard IPv4 and IPv6 localhost records, and emits a normalized `127.0.1.1`
# record from the configured short hostname and fully qualified host name.
# `basic_settings::network` declares this class when hosts management is enabled.
#
# @example Manage the standard hosts file
#   class { 'basic_settings::hosts':
#     server_fdqn => 'server01.example.org',
#   }
#
# @param hostname
#   Short hostname used for the `127.0.1.1` record. The default comes from Facter and falls back to the first label of
#   `server_fdqn` when unset.
#
# @param localhost_aliases
#   Additional host aliases appended to the `127.0.0.1 localhost` record. Every array item must be one non-empty host
#   token.
#
# @param server_fdqn
#   Fully qualified host name used as an optional alias on the `127.0.1.1` record. When it is unset or equal to
#   `hostname`, the alias is omitted.
#
# @api public
class basic_settings::hosts (
  Optional[String] $hostname          = $facts['networking']['hostname'],
  Array[String[1]] $localhost_aliases = [],
  String           $server_fdqn       = $facts['networking']['fqdn'],
) {
  # Reject aliases containing whitespace because every array item represents exactly one hosts-file token.
  $localhost_aliases_invalid = filter($localhost_aliases) |$localhost_alias| {
    $localhost_alias =~ /\s/
  }

  if (empty($localhost_aliases_invalid)) {
    # Allow host resources to proceed when all aliases are valid tokens.
    $localhost_aliases_fail_text = undef
  } else {
    # Record the invalid-alias error before declaring host resources.
    $localhost_aliases_fail_text = 'basic_settings::hosts localhost_aliases entries must be non-empty single tokens.'
  }

  # Normalize the short hostname and fall back to the first FQDN label when the fact is unavailable.
  if ($hostname != undef and $hostname != '' and $hostname !~ /\s/) {
    # Use the supplied short hostname when it is a valid host token.
    $hostname_correct = $hostname
  } elsif ($server_fdqn != '' and $server_fdqn !~ /\s/) {
    # Derive the short hostname from the FQDN when no valid short name is available.
    $hostname_correct = split($server_fdqn, '[.]')[0]
  } else {
    # Omit the hostname alias when neither source provides a valid name.
    $hostname_correct = undef
  }

  # Keep the FQDN alias only when it adds a distinct, non-empty host token.
  if ($server_fdqn != '' and $server_fdqn !~ /\s/ and $server_fdqn != $hostname_correct) {
    # Keep the distinct FQDN as an additional hostname alias.
    $server_fdqn_correct = $server_fdqn
  } else {
    # Omit an empty, invalid, or duplicate FQDN alias.
    $server_fdqn_correct = undef
  }

  # Build the optional 127.0.1.1 line without duplicate or empty host names.
  if ($hostname_correct != undef) {
    # Include the configured FQDN as an alias when it is available.
    if ($server_fdqn_correct != undef) {
      # Keep both hostname forms on the same hosts entry.
      $hostname_aliases = "${hostname_correct} ${server_fdqn_correct}"
    } else {
      # Use only the short hostname when no distinct FQDN remains.
      $hostname_aliases = $hostname_correct
    }
    $localhost_content = "127.0.1.1 ${hostname_aliases}\n"
  } else {
    # Omit the optional hostname entry when no valid name is available.
    $localhost_content = undef
  }

  # Write loopback entries only after all requested aliases have passed validation.
  if ($localhost_aliases_fail_text == undef) {
    # Build the IPv4 loopback record with any explicitly configured aliases.
    if (!empty($localhost_aliases)) {
      # Append the requested aliases to the IPv4 localhost entry.
      $ipv4_loopback_content = "# Managed by puppet\n127.0.0.1 localhost ${join($localhost_aliases, ' ')}\n"
    } else {
      # Keep the standard IPv4 localhost entry when no extra aliases are requested.
      $ipv4_loopback_content = "# Managed by puppet\n127.0.0.1 localhost\n"
    }

    # Own the complete hosts file through concat so later fragments remain idempotent.
    concat { '/etc/hosts':
      owner => 'root',
      group => 'root',
      mode  => '0644',
    }

    # Write the IPv4 loopback base before the host-specific alias line.
    concat::fragment { 'hosts_ipv4_loopback':
      target  => '/etc/hosts',
      content => $ipv4_loopback_content,
      order   => '01',
    }

    # Emit the Debian-style local host alias only when a usable hostname exists.
    if ($localhost_content != undef) {
      concat::fragment { 'hosts_ipv4_hostname':
        target  => '/etc/hosts',
        content => $localhost_content,
        order   => '02',
      }
    }

    # Keep the default IPv6 localhost records after all default IPv4 records.
    concat::fragment { 'hosts_ipv6_defaults':
      target  => '/etc/hosts',
      content => "\n# The following lines are desirable for IPv6 capable hosts\n::1     ip6-localhost ip6-loopback\nfe00::0 ip6-localnet\nff00::0 ip6-mcastprefix\nff02::1 ip6-allnodes\nff02::2 ip6-allrouters\n\n", # lint:ignore:140chars
      order   => '03',
    }
  } else {
    fail($localhost_aliases_fail_text)
  }
}
