require 'fog'
require 'puppet/util/fog'

Puppet::Type.type(:instance).provide(:ec2) do

  def self.connection(user,pass,region='us-west-2')
    opts = {
      :provider              => 'aws',
      :aws_access_key_id     => user,
      :aws_secret_access_key => pass,
      :region                => region,
    }
    Fog::Compute.new(opts)
  end

  def self.get_instances(compute)
    results = {}

    # Get a list of all the instances, then parse out the tags to see which ones are owned by this uer
    instances = compute.servers.each do |s|
      if s.metadata["Name"] != nil and s.metadata["CreatedBy"] == "Puppet"
        instance_name = s.metadata["Name"]
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
        connection = self.connection(user, password)
        instances = get_instances(connection)
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
