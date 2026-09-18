# @summary Preserves or generates one local SSH host identity.
#
# Internal orchestration for ssh's algorithm mapping. The parent supplies the protected directory and OpenSSH packages.
# Private and public key contents never enter the catalog; only local ownership and modes are managed.
#
# @example Manage an Ed25519 identity after declaring ssh
#   ssh::host_key { '/etc/ssh/host_keys/ssh_host_example_key':
#     bits     => 0,
#     key_type => 'ed25519',
#   }
#
# @param bits
#   ECDSA curve size or RSA key size for new keys; zero for Ed25519. Existing keys keep their size.
#
# @param key_type
#   Local ssh-keygen key type selected by the parent mapping.
#
# @param path
#   Absolute private key path, defaulting to the resource title. The public key uses the .pub suffix.
#
# @api private
define ssh::host_key (
  Integer[0]                      $bits,
  Enum['ecdsa', 'ed25519', 'rsa'] $key_type,
  Stdlib::Absolutepath            $path     = $title,
) {
  # The parent owns all operational prerequisites and selects the active host identities.
  if (defined(Class['ssh'])) {
    # Escape command arguments and select an explicit bit count only for variable-size key types.
    $path_shell = stdlib::shell_escape($path)
    $public_path_shell = stdlib::shell_escape("${path}.pub")
    $public_command_shell = stdlib::shell_escape("/usr/bin/ssh-keygen -y -f ${path_shell} > ${public_path_shell}")

    # Prepare the key-generation settings from the parent mapping.
    $key_type_shell = stdlib::shell_escape($key_type)
    $bits_shell = stdlib::shell_escape(String($bits))

    # Ed25519 has a fixed size; ECDSA and RSA require the selected bit count.
    if ($bits > 0) {
      # Select the explicit curve or RSA key size for a newly generated identity.
      $generate_command = "/usr/bin/ssh-keygen -q -t ${key_type_shell} -b ${bits_shell} -N '' -f ${path_shell}"
    } else {
      # Let Ed25519 use its fixed native size.
      $generate_command = "/usr/bin/ssh-keygen -q -t ${key_type_shell} -N '' -f ${path_shell}"
    }

    # The private key is the identity guard, regardless of whether its public counterpart exists.
    exec { "ssh_host_key_generate_${path}":
      command => $generate_command,
      creates => $path,
      require => [File[$ssh::host_key_dir], Package['openssh-client', 'openssh-server']],
    }

    # Restore only a missing public key after its private identity is available.
    exec { "ssh_host_key_public_generate_${path}":
      command => "/bin/sh -c ${public_command_shell}",
      creates => "${path}.pub",
      onlyif  => "/usr/bin/test -f ${path_shell}",
      require => Exec["ssh_host_key_generate_${path}"],
    }

    # Cryptographic formats cannot carry a Managed by puppet header; Puppet never supplies their contents.
    file { $path:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      replace => false,
      require => Exec["ssh_host_key_generate_${path}"],
    }

    # Public keys contain no private material; the parent directory restricts access to root.
    file { "${path}.pub":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      replace => false,
      require => Exec["ssh_host_key_public_generate_${path}"],
    }
  } else {
    fail('ssh::host_key requires class ssh to be declared first')
  }
}
