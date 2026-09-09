require 'rake/testtask'

Rake::TestTask.new(:spec) do |task|
  task.pattern = '.tools/lint/spec/**/*_test.rb'
  task.warning = false
end

task default: :spec
