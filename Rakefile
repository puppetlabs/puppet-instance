require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec => :pre) do |t|
  t.rspec_opts = "-I "
  modules = Dir.glob('shared/*')
  modules.each {|m|
    libpath = File.join(File.expand_path(m), 'lib')
    t.rspec_opts = "-I #{libpath}"
  }
end

task :default => :spec

def sync_modules
  modules = {
    'cloud_connection' => 'https://github.com/puppetlabs/puppet-cloud_connection.git',
  }
  modules.each {|name,url|
    %x{git clone #{url} shared/#{name}} unless File.directory?("shared/#{name}")
  }
end

task :pre do
  Dir.mkdir('shared') unless File.directory?('shared')
  sync_modules
end

