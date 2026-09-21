# @summary Collects a listener's shared socket options in one configuration file.
#
# The primary declaration owns the shared file and its listen directive. Other declarations contribute options to
# that same file, including declarations from vhosts evaluated later. Equal overrides merge; conflicting values fail
# catalog compilation. The parent configuration directory purges unused files.
#
# @example Internal shared HTTP listener for an existing vhost configuration file
#   nginx::listen { 'tcp 0.0.0.0:80':
#     address         => '0.0.0.0:80',
#     config_file     => '/etc/nginx/conf.d/example.conf',
#     flags           => [],
#     path            => '/etc/nginx/conf.d/listen-example.inc',
#     primary         => true,
#     restart_service => true,
#     settings        => { 'backlog' => 512 },
#     socket          => 'tcp 0.0.0.0:80',
#   }
#
# @param address
#   Listen address and port prepared by the server manifest.
#
# @param config_file
#   Existing vhost file resource that includes or shares this listener; the shared file is installed before it.
#
# @param flags
#   Protocol and default-server flags used by the primary declaration's listen directive.
#
# @param path
#   Shared snippet path under the Nginx configuration directory, with an `.inc` suffix.
#
# @param primary
#   Creates the shared file and base directive when `true`. Exactly one declaration per socket must be primary.
#   The caller includes this file once. Other declarations only contribute options and resource relationships.
#
# @param restart_service
#   Notifies Nginx when the shared file changes if any participating declaration enables notifications.
#
# @param settings
#   Effective socket options. `undef` values contribute no override; repeated equal values produce one fragment.
#
# @param socket
#   Shared identity containing the transport, address and port, used for fragments and conflict diagnostics.
#
# @api private
define nginx::listen (
  String                                            $address,
  String                                            $config_file,
  Array[String]                                     $flags,
  String                                            $path,
  Boolean                                           $primary,
  Boolean                                           $restart_service,
  Hash[String, Optional[Variant[Integer, Boolean]]] $settings,
  String                                            $socket,
) {
  # The parent owns the configuration directory, package and service used by all socket snippets.
  if defined(Class['nginx']) {
    # Only the declaration whose vhost includes the snippet owns its base directive.
    if $primary {
      concat { $path:
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        require => [Package['nginx'], File[$nginx::config]],
      }

      # Keep the managed header and listener flags before the independently collected socket options.
      concat::fragment { "nginx_listen_${socket}_header":
        target  => $path,
        content => template('nginx/listen.conf'),
        order   => '01',
      }

      # Terminate the directive only after every shared option fragment.
      concat::fragment { "nginx_listen_${socket}_footer":
        target  => $path,
        content => ";\n",
        order   => '99',
      }
    }

    # Install the complete shared directive before any participating vhost can trigger a reload.
    Concat[$path] -> File[$config_file]

    # Any participating vhost can request reloads, including when the primary declaration opts out.
    if $restart_service {
      Concat[$path] ~> Service['nginx']
    }

    # Register only effective overrides; disabled defaults do not veto another vhost's shared setting.
    $settings.each |$setting, $value| {
      # A missing override neither contributes a fragment nor conflicts with an enabled option.
      if $value != undef {
        # Fragment identities are shared by all vhosts on this socket, independently of evaluation order.
        $fragment = "nginx_listen_${socket}_${setting}"
        $content = $value ? { true => " ${setting}", default => " ${setting}=${value}" }

        # Reject different values before ensure_resource would report a generic duplicate resource.
        if !defined(Concat::Fragment[$fragment]) or getparam(Concat::Fragment[$fragment], 'content') == $content {
          ensure_resource('concat::fragment', $fragment, {
            'target'  => $path,
            'content' => $content,
            'order'   => "50-${setting}",
          })
        } else {
          # Include both conflicting values and the affected socket in the compilation error.
          $previous = strip(getparam(Concat::Fragment[$fragment], 'content'))
          fail("Conflicting global NGINX setting '${setting}' for ${socket}: ${previous} and ${strip($content)}")
        }
      }
    }
  } else {
    fail('The nginx class must be included before using the nginx::listen defined type.')
  }
}
