require "rubygems"
require "bundler/setup"

Bundler.require(:default)

task(:default)

require "standard/rake"
Rake::Task[:default].enhance([:standard])

begin
  require "rspec/core/rake_task"

  desc("Run all specs in spec directory (excluding plugin specs)")
  RSpec::Core::RakeTask.new(:spec)

  Rake::Task[:default].enhance([:spec])
rescue LoadError
end
