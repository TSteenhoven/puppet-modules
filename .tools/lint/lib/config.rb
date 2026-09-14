# frozen_string_literal: true

require 'puppet-lint'

lint_root = File.expand_path('../../..', __dir__)
config = File.join(lint_root, '.puppet-lint.rc')
abort "Missing shared lint file: #{config}" unless File.file?(config)

# Puppet-lint resolves --load paths from the working directory, including in nested option files.
Dir.chdir(lint_root) do
  PuppetLint::OptParser.build(['--no-config', '--config', config])
end
