# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'lint-project'
  spec.version = '0.1.8'
  spec.summary = 'Project Puppet-lint checks, Puppet validation, RuboCop, and JUnit reports'
  spec.authors = ['Puppet modules maintainers']
  spec.license = 'Apache-2.0'
  spec.homepage = 'https://github.com/DevSysEngineer/puppet-modules'
  spec.required_ruby_version = '>= 3.2'
  spec.files = Dir.chdir(__dir__) { Dir['lib/**/*.rb', 'bin/*', 'config/*', 'README.md', 'LICENSE'] }
  spec.bindir = 'bin'
  spec.executables = %w[puppet-lint-junit puppet-validate-junit]
  spec.require_paths = ['lib']

  spec.add_dependency 'builder', '~> 3.3'
  spec.add_dependency 'openvox', '~> 8.29'
  spec.add_dependency 'puppet-lint', '~> 5.1'
  spec.add_dependency 'puppet-lint-param-types', '~> 3.0'
  spec.add_dependency 'puppet-lint-trailing_comma-check', '~> 3.0'
  spec.add_dependency 'rubocop', '~> 1.91'
  spec.add_dependency 'syslog', '~> 0.4'
end
