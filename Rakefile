require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:isolation) do |t|
  t.test_files = FileList['test/isolation/**/*_test.rb']
end

Rake::TestTask.new(:database) do |t|
  t.test_files = FileList['test/database/**/*_test.rb']
end