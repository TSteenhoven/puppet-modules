class basic_settings::package_gitlab (
  Enum['list','822']  $deb_version,
  Boolean             $enable,
  String              $os_parent,
  String              $os_name
) {
  # Reload source list
  exec { 'package_gitlab_source_reload':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
  }

  # Check if we need newer format for APT
  if ($deb_version == '822') {
    $file = '/etc/apt/sources.list.d/gitlab.sources'
  } else {
    $file = '/etc/apt/sources.list.d/gitlab.list'
  }

  if ($enable) {
    # Get source
    if ($deb_version == '822') {
      $source  = "Types: deb\nURIs: https://packages.gitlab.com/gitlab/gitlab-ee/${os_parent}\nSuites: ${os_name}\nComponents: main\nSigned-By:/usr/share/keyrings/gitlab.gpg\n"
    } else {
      $source = "deb [signed-by=/usr/share/keyrings/gitlab.gpg] https://packages.gitlab.com/gitlab/gitlab-ee/${os_parent} ${os_name} main\n"
    }

    # Install Gitlab repo
    exec { 'package_gitlab_source':
      command => "/usr/bin/printf \"# Managed by puppet\n${source}\" > ${file}; /usr/bin/curl -fsSL https://packages.gitlab.com/gitlab/gitlab-ee/gpgkey | gpg --dearmor | tee /usr/share/keyrings/gitlab.gpg >/dev/null; chmod 644 /usr/share/keyrings/gitlab.gpg",
      unless  => "[ -e ${file} ]",
      notify  => Exec['package_gitlab_source_reload'],
      require => [Package['curl'], Package['gnupg']],
    }
  } else {
    # Remove Nginx repo
    exec { 'package_gitlab_source':
      command => "/usr/bin/rm ${file}",
      onlyif  => "[ -e ${file} ]",
      notify  => Exec['package_gitlab_source_reload'],
    }
  }
}
