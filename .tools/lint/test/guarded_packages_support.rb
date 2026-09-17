# frozen_string_literal: true

# Synthetic inputs shared by detection, fix and packaged CLI tests.
module GuardedPackagesSupport
  def guard(name, attributes = 'ensure => installed,', extra: '')
    <<~PUPPET
        if (!defined(Package['#{name}'])) {
          package { '#{name}':
            #{attributes}
          }
      #{"    #{extra}\n" unless extra.empty?}  }
    PUPPET
  end

  def manifest(*guards, declaration: 'class example')
    "#{declaration} {\n#{guards.join("\n")}\n}\n"
  end

  def pair(attributes = 'ensure => installed,', **options)
    manifest(guard('alpha', attributes, **options), guard('beta', attributes, **options))
  end

  def merged
    <<~PUPPET
      class example {
        ensure_packages(
          [
            'alpha',
            'beta',
          ],
          {
            'ensure' => 'installed',
          },
        )

      }
    PUPPET
  end
end
