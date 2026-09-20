# @summary Manages RabbitMQ Erlang and server APT repositories.
#
# This private helper writes or removes the RabbitMQ Erlang and RabbitMQ Server package sources and signing keys. It is
# called by `basic_settings` after OS support has been calculated.
#
# @example Internal use from basic_settings
#   class { 'basic_settings::package_rabbitmq':
#     deb_version => 'list',
#     enable      => true,
#     os_name     => 'bookworm',
#     os_parent   => 'debian',
#   }
#
# @param deb_version
#   APT source format to manage: `list` or `822`.
#
# @param enable
#   Creates both repositories and imports keys when `true`; removes them when `false`.
#
# @param os_name
#   Distribution codename used in repository paths and suites.
#
# @param os_parent
#   Distribution family used in repository paths.
#
# @api private
class basic_settings::package_rabbitmq (
  Enum['list', '822'] $deb_version,
  Boolean             $enable,
  String              $os_name,
  String              $os_parent,
) {
  # Provide the shell and source-list tools on both installation and removal paths.
  $source_packages = ['apt', 'coreutils', 'dash']
  ensure_packages($source_packages, {
    'ensure'          => 'installed',
    'install_options' => ['--no-install-recommends', '--no-install-suggests'],
  })

  # Check if we need newer format for APT
  if ($deb_version == '822') {
    # Use separate deb822 source files for Erlang and RabbitMQ.
    $file_erlang = '/etc/apt/sources.list.d/rabbitmq-erlang.sources'
    $file_server = '/etc/apt/sources.list.d/rabbitmq-server.sources'
  } else {
    # Use separate one-line APT source files for Erlang and RabbitMQ.
    $file_erlang = '/etc/apt/sources.list.d/rabbitmq-erlang.list'
    $file_server = '/etc/apt/sources.list.d/rabbitmq-server.list'
  }

  # Set keys
  $key_erlang = '/usr/share/keyrings/rabbitmq-erlang.gpg'
  $key_server = '/usr/share/keyrings/rabbitmq-server.gpg'

  # Escape repository paths before using them in exec commands and guards.
  $file_erlang_shell = stdlib::shell_escape($file_erlang)
  $file_server_shell = stdlib::shell_escape($file_server)
  $key_erlang_shell = stdlib::shell_escape($key_erlang)
  $key_server_shell = stdlib::shell_escape($key_server)

  # Install the RabbitMQ and Erlang repositories or remove their managed sources when disabled.
  if ($enable) {
    # Install the download and signing tools only while this repository is enabled.
    $repository_packages = ['apt-transport-https', 'ca-certificates', 'curl', 'gnupg']
    ensure_packages($repository_packages, {
      'ensure'          => 'installed',
      'install_options' => ['--no-install-recommends', '--no-install-suggests'],
    })
    $repository_required_packages = concat($source_packages, $repository_packages)

    # Get source
    if ($deb_version == '822') {
      # Render the Erlang and RabbitMQ repositories with their signing keys in deb822 format.
      $source_erlang  = "Types: deb\\nURIs: https://deb1.rabbitmq.com/rabbitmq-erlang/${os_parent}/${os_name}\\nSuites: ${os_name}\\nComponents: main\\nSigned-By:${key_erlang}\\n" # lint:ignore:140chars
      $source_server  = "Types: deb\\nURIs: https://deb1.rabbitmq.com/rabbitmq-server/${os_parent}/${os_name}\\nSuites: ${os_name}\\nComponents: main\\nSigned-By:${key_server}\\n" # lint:ignore:140chars
    } else {
      # Render the Erlang and RabbitMQ repositories with their signing keys in one-line APT format.
      $source_erlang = "deb [signed-by=${key_erlang}] https://deb1.rabbitmq.com/rabbitmq-erlang/${os_parent}/${os_name} ${os_name} main\\n"
      $source_server = "deb [signed-by=${key_server}] https://deb1.rabbitmq.com/rabbitmq-server/${os_parent}/${os_name} ${os_name} main\\n"
    }

    # Escape generated repo content as literal newline sequences before the shell writes it.
    $source_erlang_shell = stdlib::shell_escape("# Managed by puppet\\n${source_erlang}")
    $source_server_shell = stdlib::shell_escape("# Managed by puppet\\n${source_server}")

    # Install Rabbitmq erlang repo
    exec { 'package_rabbitmq_erlang_source':
      command => "/usr/bin/printf %b ${source_erlang_shell} > ${file_erlang_shell}; /usr/bin/curl -fsSL https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA | gpg --dearmor | tee ${key_erlang_shell} >/dev/null; chmod 644 ${key_erlang_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_erlang_shell}",
      require => Package[$repository_required_packages],
    }

    # Install Rabbitmq server repo
    exec { 'package_rabbitmq_server_source':
      command => "/usr/bin/printf %b ${source_server_shell} > ${file_server_shell}; /usr/bin/curl -fsSL https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA | gpg --dearmor | tee ${key_server_shell} >/dev/null; chmod 644 ${key_server_shell}; /usr/bin/apt-get update", # lint:ignore:140chars
      unless  => "/usr/bin/test -e ${file_server_shell}",
      require => Package[$repository_required_packages],
    }
  } else {
    # Remove Rabbitmq erlang repo
    exec { 'package_rabbitmq_erlang_source':
      command => "/usr/bin/rm ${file_erlang_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_erlang_shell}",
      require => Package[$source_packages],
    }

    # Remove Rabbitmq server repo
    exec { 'package_rabbitmq_server_source':
      command => "/usr/bin/rm ${file_server_shell} && /usr/bin/apt-get update",
      onlyif  => "/usr/bin/test -e ${file_server_shell}",
      require => Package[$source_packages],
    }

    # Remove rabbitmq key
    file { 'package_proxmox_key_erlang':
      ensure => absent,
      path   => $key_erlang,
    }

    # Remove the RabbitMQ server key independently of the Erlang repository key.
    file { 'package_proxmox_key_server':
      ensure => absent,
      path   => $key_server,
    }
  }
}
