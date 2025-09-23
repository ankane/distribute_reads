require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  # TODO remove when active_record_proxy_adapters > 0.8.0 released
  t.warning = false # for active_record_proxy_adapters
end

task default: :test
