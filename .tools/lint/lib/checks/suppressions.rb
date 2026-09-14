# frozen_string_literal: true

module ProjectLint
  # Restrict real lint controls while allowing ordinary prose mentioning directives.
  module SuppressionsCheck
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
      controls == ['lint:endignore'] || (controls.any? && controls.all? { |control| ALLOWED.include?(control) })
    end
  end
end
