require 'rubygems'
require 'rspec/core/rake_task'
require "#{File.dirname(__FILE__)}/lib/r509/middleware/validity/version"

task :default => :spec
RSpec::Core::RakeTask.new(:spec)

desc 'Run all rspec tests with rcov (1.8 only)'
RSpec::Core::RakeTask.new(:rcov) do |t|
	t.rcov_opts =  %q[--exclude "spec,gems"]
	t.rcov = true
end

namespace :gem do
desc 'Build the gem'
    task :build do
        puts `yard`
        puts `gem build r509-middleware-validity.gemspec`
    end

    desc 'Install gem'
    task :install do
        puts `gem install r509-middleware-validity-#{R509::Middleware::Validity::VERSION}.gem`
    end

    desc 'Uninstall gem'
    task :uninstall do
        puts `gem uninstall r509-middleware-validity`
    end
end

desc 'Build yard documentation'
task :yard do
	puts `yard`
	`open doc/index.html`
end
