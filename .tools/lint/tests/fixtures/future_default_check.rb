# frozen_string_literal: true

require 'puppet-lint'
PuppetLint.new_check(:future_default_check) do
  def check
    notify(:warning, message: 'New default check is active', line: 1, column: 1)
  end
end
