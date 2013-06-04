require 'fog'
require 'puppet/util/fog'

Puppet::Type.type(:instance).provide(:ec2) do

  def self.connection(user,pass,region='us-west-2')
    opts = {
      :provider              => 'AWS',
      :aws_access_key_id     => user,
      :aws_secret_access_key => pass,
      :region                => region,
    }
    Fog::Compute.new(opts)
  end

  #
  # figure out which instances currently exist!
  #
  # this is a little complicated... for performance reasons.
  # I wanted to do a single operation to calculate all of the 
  # instance information
  def self.prefetch(resources)
    if resources.is_a? Hash
      resources_by_user = {}
      users = {}
      resources.each do |name, resource|
        resources_by_user[resource[:user]] ||= []
        resources_by_user[resource[:user]] << resource
        users[resource[:user]] ||= resource[:pass]
      end
      users.each do |user, password|
        resources = resources_by_user[user]
        connection = self.connection(user, password)
        instances = Puppet::Util::Fog.user_instances(connection)
        resources_by_user[user].each do |res|
          if instances and instances[res[:name]]
            res.provider = instances[res[:name]]
          end
        end
      end
    else
      raise Puppet::Error, "resources must be a hash"
    end
  end

  def create
    tags = {:Name => resource[:name], :CreatedBy => 'Puppet'}
    ec2 = self.class.connection(resource[:user], resource[:pass])
    ec2.servers.create(:image_id => resource[:image],
                       :flavor_id => resource[:flavor],
                       :tags => tags)
  end

  def destroy
    ec2 = self.class.connection(resource[:user], resource[:pass])
    instance = ec2.servers.get(@property_hash[:id])
    instance.destroy
  end

  def exists?
    debug @property_hash.inspect
    !(@property_hash[:ensure] == :absent or @property_hash.empty?)
  end

  #
  # Short of storing credentials on disk somewhere and then referencing them, I
  # don't see how this will work.
  #
  def self.instances
    raise Puppet::Error, 'instances does not work for ec2, a username and password is needed'
  end

end
