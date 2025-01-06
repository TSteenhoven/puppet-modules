define letsencrypt::certificate (
  Array                       $domains,
  Enum['present','absent']    $ensure     = present,
  String                      $plugin     = 'nginx',
) {
  # Try to get require
  case $plugin {
    'nginx': {
      $require = [Package['certbot'], Package['grep'], Package['python3-certbot-nginx']]
    }
    default: {
      $require = [Package['certbot'], Package['grep']]
    }
  }

  # Set binary
  $cerbot_bin = '/usr/bin/certbot'

  # Run command based on ensure
  case $ensure {
    'present': {
      # Convert array to string
      $domain_sort = $domains.sort();
      $domain_list_install = join($domain_sort, ' -d ')
      $domain_list_find = join($domain_sort, ' ')

      # Check if fullchain.pem and privkey.pem exists
      exec { "letsencrypt_certificate_${name}":
        command => "${cerbot_bin} run --${plugin} -n --cert-name ${name} -d ${domain_list_install}",
        unless  => "${cerbot_bin} certificates -n --cert-name ${name} | /usr/bin/grep 'Domains: ${domain_list_find}'",
        require => $require,
      }
    }
    'absent': {
      # Delete fullchain.pem and privkey.pem
      exec { "letsencrypt_certificate_${name}":
        command => "${cerbot_bin} delete --${plugin} --cert-name ${name}",
        onlyif  => "${cerbot_bin} certificates -n --cert-name ${name} | /usr/bin/grep 'Certificate Name: ${name}'",
        require => $require,
      }
    }
    default: {
      fail('Unknown ensure: $ensure, must be present or absent')
    }
  }
}
