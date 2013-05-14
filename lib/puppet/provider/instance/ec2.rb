require 'fog'

Puppet::Type.type(:instance).provide(:ec2) do

  def self.new_ec2(user,pass)
    opts = {
      :provider              => 'AWS',
      :aws_access_key_id     => user,
      :aws_secret_access_key => pass,
      :region                => 'us-west-2',
    }
    Fog::Compute.new(opts)
  end

  def self.user_instances(ec2)
    results = {}
    # Get a list of all the instances, then parse out the tags to see which ones I have created
    instances = ec2.servers.each do |s|
      if s.tags["Name"] != nil and s.tags["CreatedBy"] == "Puppet"
        instance_name = s.tags["Name"]
        results[instance_name] = new(
          :name   => instance_name,
          :ensure => s.state.to_sym,
          :id     => s.id,
          :flavor => s.flavor_id,
          :image  => s.image_id,
          :status => s.state,
        )
      end
    end
    results
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
        ec2 = self.new_ec2(user, password)
        instances = self.user_instances(ec2)
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
    ec2 = self.class.new_ec2(resource[:user], resource[:pass])
    ec2.servers.create(:image_id => resource[:image],
                       :flavor_id => resource[:flavor],
                       :tags => tags)
  end

  def destroy
    ec2 = self.class.new_ec2(resource[:user], resource[:pass])
    instance = ec2.servers.get(@property_hash[:id])
    instance.destroy
  end

  def exists?
    debug @property_hash.inspect
    #@property_hash[:ensure] == :present
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
