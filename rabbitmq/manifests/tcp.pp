# @summary Manages RabbitMQ AMQP TCP and TLS listener configuration.
#
# This class requires `rabbitmq` and writes `/etc/rabbitmq/conf.d/tcp.conf`.
# lint:ignore:140chars
# When all certificate paths are provided, TLS is enabled and plain TCP follows `tcp_enable`; otherwise TLS is disabled and plain TCP is forced on so the broker remains reachable.
# lint:endignore
#
# @example Enable TLS and disable plain TCP
#   class { 'rabbitmq::tcp':
#     ssl_ca_certificate  => '/etc/rabbitmq/ssl/ca.pem',
#     ssl_certificate     => '/etc/rabbitmq/ssl/cert.pem',
#     ssl_certificate_key => '/etc/rabbitmq/ssl/key.pem',
#     tcp_enable          => false,
#   }
#
# @param ssl_ca_certificate
#   Optional CA certificate path for TLS listeners.
#
# @param ssl_certificate
#   Optional certificate path for TLS listeners.
#
# @param ssl_certificate_key
#   Optional private key path for TLS listeners.
#
# @param ssl_ciphers
#   TLS cipher list rendered into RabbitMQ configuration.
#
# @param ssl_port
#   TLS AMQP listener port.
#
# @param ssl_protocols
#   TLS protocol list rendered into RabbitMQ configuration.
#
# @param tcp_enable
#   Enables the plain TCP listener when TLS is available. Plain TCP is forced on when TLS certificate inputs are incomplete.
#
# @param tcp_port
#   Plain AMQP listener port.
#
# @api public
class rabbitmq::tcp (
  Optional[String] $ssl_ca_certificate  = undef,
  Optional[String] $ssl_certificate     = undef,
  Optional[String] $ssl_certificate_key = undef,
  Array            $ssl_ciphers         = [
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
  ],
  Integer          $ssl_port            = 5671,
  Array            $ssl_protocols       = ['tlsv1.3', 'tlsv1.2'],
  Boolean          $tcp_enable          = false,
  Integer          $tcp_port            = 5672,
) {
  if (defined(Class['rabbitmq'])) {
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
  } else {
    fail('The rabbitmq class must be included before using the rabbitmq::tcp class type.')
  }
}
