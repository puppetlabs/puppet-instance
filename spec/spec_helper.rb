dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.join(dir, 'lib')

require 'puppet'
require 'test/unit'
require 'mocha/setup'
require 'helpers'

gem 'rspec'

RSpec.configure do |config|
  config.mock_with :mocha
  config.include Helpers
end

