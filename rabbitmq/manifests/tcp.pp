class rabbitmq::tcp (
  Boolean             $tcp_enable             = false,
  Integer             $tcp_port               = 5672,
  Optional[String]    $ssl_ca_certificate     = undef,
  Optional[String]    $ssl_certificate        = undef,
  Optional[String]    $ssl_certificate_key    = undef,
  Integer             $ssl_port               = 5671,
  Array               $ssl_protocols          = ['tlsv1.3', 'tlsv1.2'],
  Array               $ssl_ciphers            = [
    'TLS_AES_256_GCM_SHA384',
    'TLS_AES_128_GCM_SHA256',
    'TLS_CHACHA20_POLY1305_SHA256',
    'TLS_AES_128_CCM_SHA256',
    'TLS_AES_128_CCM_8_SHA256',
    'ECDHE-ECDSA-AES128-CCM',
    'ECDHE-ECDSA-AES128-CCM8',
    'ECDHE-ECDSA-AES256-CCM',
    'ECDHE-ECDSA-AES256-CCM8',
    'ECDHE-RSA-AES128-GCM-SHA256',
    'ECDHE-RSA-AES256-GCM-SHA384',
    'ECDHE-RSA-CHACHA20-POLY1305',
  ]
) {
  # Check if all cert variables are given
  if ($ssl_ca_certificate != undef and $ssl_certificate != undef and $ssl_certificate_key != undef) {
    $tls_allow = true
    $tcp_enable_correct = $tcp_enable
  } else {
    $tls_allow = false
    $tcp_enable_correct = true
  }

  # Create management config file
  file { '/etc/rabbitmq/conf.d/tcp.conf':
    ensure  => file,
    content => template('rabbitmq/tcp.conf'),
    owner   => 'rabbitmq',
    group   => 'rabbitmq',
    mode    => '0600',
    notify  => Service['rabbitmq-server'],
    require => File['rabbitmq_config_dir'],
  }
}
