# @summary Registers or removes one named S3 objectstore through Nextcloud OCC.
#
# Declare docker first and provide the initialized Nextcloud AIO deployment required by docker::nextcloud_occ.
# The resource name is the key below objectstore; only that complete subtree is managed.
# Other stores and the default/root selections are preserved. Registration does not activate primary storage.
# Names start with a letter or digit and use letters, digits, dots, underscores and hyphens.
# The names default, root, class and arguments are reserved.
# Unspecified optional arguments are omitted, including on updates that remove a previously configured override.
# Nextcloud owns their defaults. PHP-style option names are mapped from the snake_case Puppet parameters below.
# Changes to active primary storage require a separate migration plan; removing a store still in use loses access.
#
# @example Register an S3-compatible store without selecting it as default
#   docker::nextcloud_s3 { 'server1':
#     compose_name   => 'nextcloud-aio',
#     bucket         => 'nextcloud-01',
#     hostname       => 's3.example.org',
#     key            => 'replace-with-access-key',
#     secret         => Sensitive('replace-with-secret'),
#     use_path_style => true,
#   }
#
# @param compose_name
#   Title of the managed docker::compose resource and project label passed to docker::nextcloud_occ.
#   The standard AIO deployment uses nextcloud-aio.
#
# @param bucket
#   S3 bucket name, required when present. Defaults to undef. Use a unique, AWS-compatible bucket per store.
#
# @param concurrency
#   Maximum concurrent multipart uploads. Positive integer; undef leaves the Nextcloud default.
#
# @param connect_timeout
#   S3 connection timeout in seconds, including fractional seconds. Zero disables it; undef leaves the Nextcloud
#   default.
#
# @param copy_size_limit
#   Single-copy size limit in bytes (copySizeLimit). Undef leaves the Nextcloud default.
#
# @param ensure
#   Present manages the named store; absent deletes only that store and needs no credentials. Defaults to present.
#   Before removal, migrate its data and separately change any default/root selection or user mappings referring to it.
#
# @param hostname
#   S3 endpoint hostname without scheme or bucket prefix. Undef leaves Nextcloud's Amazon endpoint selection.
#
# @param key
#   Access key ID, required when present. Accepts String or Sensitive[String]; defaults to undef.
#
# @param legacy_auth
#   True requests legacy signature v2; false keeps the normal signature provider. Undef omits the option.
#
# @param occ_timeout
#   Maximum seconds per OCC operation, default 120. Independent of S3 connection and request timeouts.
#
# @param port
#   S3 endpoint TCP port, 1 through 65535. Undef leaves Nextcloud's scheme-dependent default.
#
# @param proxy
#   Proxy URL, optionally Sensitive when it contains credentials; false disables the proxy. Undef omits the option.
#
# @param put_size_limit
#   Single-PUT size limit in bytes (putSizeLimit). Undef leaves the Nextcloud default.
#
# @param region
#   S3 region. Undef leaves Nextcloud's region selection; neither region nor hostname is required by this define.
#
# @param secret
#   Secret access key as Sensitive[String], required when present. Defaults to undef; ignored when absent.
#
# @param sse_c_key
#   Sensitive base64-encoded 32-byte SSE-C encryption key. Undef omits the option; retain keys needed to decrypt data.
#
# @param storage_class
#   Object storage class (storageClass), for example STANDARD_IA. Undef leaves the Nextcloud default.
#
# @param timeout
#   S3 timeout in whole seconds; zero disables it. Undef leaves the Nextcloud default.
#   Nextcloud stores this setting in an integer property; fractional values are supported only by connect_timeout.
#
# @param upload_part_size
#   Multipart upload part size in bytes (uploadPartSize). Must be at least 5 MiB; undef leaves the Nextcloud default.
#
# @param use_multipart_copy
#   True enables multipart copy and false disables it (useMultipartCopy). Undef leaves the Nextcloud default.
#
# @param use_path_style
#   True addresses buckets in the URL path; false uses virtual-host addressing. Undef leaves the Nextcloud default.
#
# @param use_ssl
#   True uses HTTPS; false explicitly permits unencrypted S3 traffic. Undef leaves the Nextcloud default.
#
# @param verify_bucket_exists
#   True checks bucket existence; false skips that check. Undef leaves the Nextcloud default.
#   Disable only after provisioning the bucket; multibucket deployments may need the check.
#
# @param version
#   AWS S3 API version, such as latest or 2006-03-01. Undef leaves the Nextcloud default.
#
# @api public
define docker::nextcloud_s3 (
  Pattern[/\A[A-Za-z0-9_.-]+\z/]                              $compose_name,
  Optional[String[1]]                                         $bucket               = undef,
  Optional[Integer[1]]                                        $concurrency          = undef,
  Optional[Variant[Integer[0], Float[0]]]                     $connect_timeout      = undef,
  Optional[Integer[1]]                                        $copy_size_limit      = undef,
  Enum['present', 'absent']                                   $ensure               = present,
  Optional[String[1]]                                         $hostname             = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]]          $key                  = undef,
  Optional[Boolean]                                           $legacy_auth          = undef,
  Integer[1]                                                  $occ_timeout          = 120,
  Optional[Integer[1, 65535]]                                 $port                 = undef,
  Optional[Variant[Boolean, String[1], Sensitive[String[1]]]] $proxy                = undef,
  Optional[Integer[1]]                                        $put_size_limit       = undef,
  Optional[String[1]]                                         $region               = undef,
  Optional[Sensitive[String[1]]]                              $secret               = undef,
  Optional[Sensitive[String[1]]]                              $sse_c_key            = undef,
  Optional[String[1]]                                         $storage_class        = undef,
  Optional[Integer[0]]                                        $timeout              = undef,
  Optional[Integer[5242880]]                                  $upload_part_size     = undef,
  Optional[Boolean]                                           $use_multipart_copy   = undef,
  Optional[Boolean]                                           $use_path_style       = undef,
  Optional[Boolean]                                           $use_ssl              = undef,
  Optional[Boolean]                                           $verify_bucket_exists = undef,
  Optional[String[1]]                                         $version              = undef,
) {
  # Docker supplies the host runtime; the OCC wrapper owns the AIO invocation.
  if (defined(Class['docker'])) {
    # Reject selection keys and the legacy single-store fields so this resource only owns a named store.
    if ($name =~ /\A[A-Za-z0-9][A-Za-z0-9_.-]*\z/ and !($name in ['default', 'root', 'class', 'arguments'])) {
      # Removal needs only a name; creation requires the three S3 credentials/settings.
      if ($ensure == absent or ($bucket != undef and $key != undef and $secret != undef and $proxy != true)) {
        # Serialize real Puppet data and preserve false, integer and fractional values without copying defaults.
        if ($ensure == present) {
          # Keep the public snake_case names independent of Nextcloud's mixed-case configuration keys.
          $arguments = {
            'bucket'               => $bucket,
            'key'                  => $key,
            'secret'               => $secret,
            'region'               => $region,
            'storageClass'         => $storage_class,
            'hostname'             => $hostname,
            'use_ssl'              => $use_ssl,
            'use_path_style'       => $use_path_style,
            'port'                 => $port,
            'sse_c_key'            => $sse_c_key,
            'concurrency'          => $concurrency,
            'proxy'                => $proxy,
            'connect_timeout'      => $connect_timeout,
            'timeout'              => $timeout,
            'uploadPartSize'       => $upload_part_size,
            'putSizeLimit'         => $put_size_limit,
            'useMultipartCopy'     => $use_multipart_copy,
            'copySizeLimit'        => $copy_size_limit,
            'legacy_auth'          => $legacy_auth,
            'version'              => $version,
            'verify_bucket_exists' => $verify_bucket_exists,
          }.filter |$option, $value| { $value != undef }.reduce({}) |$result, $entry| {
            # Only protected serialization needs the raw credential values.
            $value = $entry[1] ? {
              Sensitive => $entry[1].unwrap,
              default   => $entry[1],
            }
            $result + { $entry[0] => $value }
          }
          $objectstore_json = stdlib::to_json({
            'class'     => '\OC\Files\ObjectStore\S3',
            'arguments' => $arguments,
          })
          $command = ['config:system:set', '--type=json', Sensitive("--value=${objectstore_json}"), 'objectstore', $name]
          $expected_json = Sensitive($objectstore_json)
        } else {
          # OCC renders the explicit missing-value fallback as a JSON string, distinct from any objectstore object.
          $command = ['config:system:delete', 'objectstore', $name]
          $expected_json = '"null"'
        }

        # Read the named subtree as JSON; the explicit missing-value fallback distinguishes absence from an object.
        docker::nextcloud_occ { "s3_${name}":
          command      => $command,
          compose_name => $compose_name,
          timeout      => $occ_timeout,
          unless       => ['config:system:get', '--output=json', '--default-value=null', 'objectstore', $name],
          unless_json  => $expected_json,
        }
      } else {
        fail('docker::nextcloud_s3 requires bucket, key and secret when present; proxy must be a URL or false.')
      }
    } else {
      fail('docker::nextcloud_s3 requires a valid objectstore name; default, root, class and arguments are reserved.')
    }
  } else {
    fail('docker::nextcloud_s3 requires the docker class before its declaration.')
  }
}
