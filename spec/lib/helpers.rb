module Helpers

  require 'fog'

  TEST_DIR = Pathname.new(__FILE__).parent + '..'

  TYPE = {
    :instance => :ec2
  }

  Fog.mock!

end
