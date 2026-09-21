# frozen_string_literal: true

# Small shared inputs for native, CLI and installed-gem checks of package-list reuse.
module ResourceListReuseSupport
  RULE = :project_resource_list_reuse

  def pair(installation = "['alpha', 'beta', 'gamma']", dependency = "'alpha', 'beta', 'gamma'", attribute: 'require')
    <<~PUPPET
      class example {
        # Install the shared tools.
        ensure_packages(#{installation}, { 'ensure' => 'installed' })

        # Order the consumer after its prerequisites.
        notify { 'consumer':
          #{attribute} => Package[#{dependency}],
        }
      }
    PUPPET
  end

  def shared_pair
    pair('$required_packages', '$required_packages').sub(
      '  ensure_packages(', "  $required_packages = ['alpha', 'beta', 'gamma']\n\n  ensure_packages("
    )
  end

  def documented_pair(code = pair)
    <<~PUPPET + code
      # @summary Installs shared tools for the example consumer.
      #
      # @example Install the tools
      #   include example
      #
      # @api public
    PUPPET
  end
end
