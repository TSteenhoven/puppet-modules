require 'rake/testtask'

{
  test: ['Run all tool tests', '.tools/test/**/*_test.rb'],
  'test:lint' => ['Run linter tests', '.tools/test/lint/**/*_test.rb'],
}.each do |name, (description, pattern)|
  Rake::TestTask.new(name) do |task|
    task.description = description
    task.pattern = pattern
    task.warning = false
  end
end

task default: :test
