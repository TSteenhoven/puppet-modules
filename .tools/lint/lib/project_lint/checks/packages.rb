# frozen_string_literal: true

require 'project_lint/resource_attributes'

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Check APT installation options after resolving local resource defaults.
    module Packages
      include ResourceAttributes

      def check
        ast.resource_bodies('package').each do |resource, body, parents|
          attrs = attributes(resource, body, parents)
          next unless apt_installation?(attrs)

          message = installation_problem(resource, parents, attrs)
          issue(body.title, message) if message
        end
      end

      def apt_installation?(attrs)
        return false if %w[absent purged].include?(literal(attrs['ensure']))

        provider = literal(attrs['provider'])
        !provider || %w[apt aptitude].include?(provider)
      end

      def installation_problem(resource, parents, attrs)
        if attrs['provider'] && literal(attrs['provider']).nil?
          '[review] Resolve the package provider before checking APT installation options'
        elsif !attrs.key?('install_options')
          missing_options_message(resource, parents)
        elsif !apt_options?(attrs['install_options'])
          '[review] Verify effective APT installation options and any concrete package requirement ' \
            'for recommends or suggests'
        end
      end

      def missing_options_message(resource, parents)
        if indirect_attributes?(resource, parents)
          '[review] Resolve inherited or overridden APT package attributes in a catalog'
        else
          'APT package installation must disable recommends and suggests or have a tested central package exception'
        end
      end
    end
    PuppetLint.new_check(:project_packages) { include Packages }
  end
end
