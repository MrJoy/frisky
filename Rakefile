require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'cucumber/rake/task'
require 'yard'


YARD::Rake::YardocTask.new
Cucumber::Rake::Task.new(:features)
RSpec::Core::RakeTask.new

# Alias for rubygems-test
task test: :spec

task default: :test

