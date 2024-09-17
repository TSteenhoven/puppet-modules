class basic_settings::package_nginx (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name
) {
  # Reload source list
  exec { 'package_nginx_source_reload':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
  }

  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/nginx.sources'
  } else {
    $file = '/etc/apt/sources.list.d/nginx.list'
  }

  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: https://nginx.org/packages/mainline/${os_parent}\nSuites: ${os_name}\nComponents: nginx\nSigned-By:/usr/share/keyrings/nginx-archive-keyring.gpg\n"
    } else {
      $source = "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/mainline/${os_parent} ${os_name} nginx\n"
    }

    # Install Nginx repo
    exec { 'package_nginx_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null; chmod 644 /usr/share/keyrings/nginx-archive-keyring.gpg",
      unless  => "[ -e ${file} ]",
      notify  => Exec['package_nginx_source_reload'],
      require => [Package['curl'], Package['gnupg']],
    }
  } else {
    # Remove Nginx repo
    exec { 'package_nginx_source':
      command => "/usr/bin/rm ${file}",
      onlyif  => "[ -e ${file} ]",
      notify  => Exec['package_nginx_source_reload'],
    }
  }
}
