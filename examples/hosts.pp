# Hosts examples for managing `/etc/hosts` through concat.
# Replace hostnames and addresses with environment data.

node 'hosts-basic.example.org' {
  class { 'basic_settings':
    hosts_enable            => true,
    hosts_localhost_aliases => ['puppet', 'test'],
    server_fdqn             => 'hosts-basic.example.org',
  }

  # Resolve the Puppet service through a managed hosts entry.
  basic_settings::hosts_entry { 'puppet':
    hostname => 'puppet',
    ip       => '192.0.2.10',
  }

  # Give the monitoring endpoint its own managed address and explanatory hosts comment.
  basic_settings::hosts_entry { 'monitoring':
    comment  => 'monitoring server',
    hostname => 'monitoring.example.org',
    ip       => '192.0.2.20',
  }
}

node 'network-only.example.org' {
  class { 'basic_settings::network':
    firewall_package => 'nftables',
    hosts_enable     => true,
    server_fdqn      => 'network-only.example.org',
  }

  # Add an internal API endpoint to the network-owned hosts configuration.
  basic_settings::hosts_entry { 'internal-api':
    comment  => 'internal api endpoint',
    hostname => 'api.internal.example.org',
    ip       => '192.0.2.30',
  }
}

node 'hosts-direct.example.org' {
  class { 'basic_settings::hosts':
    server_fdqn => 'hosts-direct.example.org',
  }

  # Add the mail relay after initializing the hosts file directly.
  basic_settings::hosts_entry { 'mail-relay':
    hostname => 'mail-relay.internal.example.org',
    ip       => '192.0.2.40',
  }
}
