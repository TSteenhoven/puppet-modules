# frozen_string_literal: true

require_relative '../model'
require_relative '../nullability'

module ProjectLint
  # Implements the project_puppet_urls check through the native Puppet-lint contract.
  module PuppetUrlsCheck
    def check
      tokens.each do |token|
        # Keep the upstream scope: literal strings and the fixed prefix before interpolation, including source arrays.
        next unless %i[SSTRING STRING DQPRE].include?(token.type) && token.value.start_with?('puppet://')
        next if token.value.match?(%r{\Apuppet://[^/]*/(?:modules|files)/})

        notify(:warning, message: 'puppet:// URL must use a modules/ or files/ mount', line: token.line,
                         column: token.column)
      end
    end

    # No automatic fix: choosing a mount changes the source and requires knowledge of the fileserver layout.
  end
end
