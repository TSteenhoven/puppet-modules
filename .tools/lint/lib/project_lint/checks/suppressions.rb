# frozen_string_literal: true

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Restrict real lint controls while allowing ordinary prose mentioning directives.
    module Suppressions
      ALLOWED = %w[lint:ignore:140chars lint:ignore:puppet_url_without_modules].freeze

      def check
        tokens.each do |token|
          next unless %i[COMMENT MLCOMMENT SLASH_COMMENT].include?(token.type)
          next unless token.value.strip.match?(/\Alint:(?:ignore|endignore)\b/)
          next if permitted_controls?(token.value)

          notify(:error, message: 'Only targeted 140chars and puppet_url_without_modules suppressions are allowed; ' \
                                  'fix other lint violations', line: token.line, column: token.column)
        end
      end

      def permitted_controls?(value)
        controls = value.strip.split.take_while { |word| word.start_with?('lint:') }
        controls == ['lint:endignore'] || (controls.any? && controls.all? do |control|
          self.class::ALLOWED.include?(control)
        end)
      end
    end
    PuppetLint.new_check(:project_suppressions) { include Suppressions }
  end
end
