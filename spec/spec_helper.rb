if (RUBY_VERSION.split('.')[1].to_i > 8)
    require 'simplecov'
    SimpleCov.start
end

$:.unshift File.expand_path("../../lib", __FILE__)
$:.unshift File.expand_path("../", __FILE__)
require 'rubygems'
require 'fixtures'
require 'rspec'
require 'rack/test'
require 'r509/middleware/validity'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end
