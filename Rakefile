# frozen_string_literal: true

require 'rake/testtask'

{
  test: ['Run all tool tests', '.tools/**/test/**/*_test.rb'],
  'test:lint' => ['Run linter tests', '.tools/lint/test/**/*_test.rb']
}.each do |name, (description, pattern)|
  Rake::TestTask.new(name) do |task|
    task.description = description
    task.pattern = pattern
    task.warning = false
  end
end

namespace :validate do
  desc 'Validate first-party Puppet manifests and write a JUnit report'
  task :puppet do
    manifests = FileList['**/*.pp'].exclude('.tools/**/*', 'vendor/**/*', 'concat/**/*', 'debconf/**/*',
                                            'reboot/**/*', 'stdlib/**/*', 'timezone/**/*')
    sh 'bundle', 'exec', 'puppet-validate-junit', '.tools/lint/results/puppet-validate-report.xml', *manifests
  end
end

task default: :test
