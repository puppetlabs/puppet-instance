require 'fog'

Puppet::Type.type(:instance).provide(:rackspace) do

  def self.connection(user,pass,region=:ord)
    opts = {
      :provider           => 'rackspace',
      :rackspace_username => user,
      :rackspace_api_key  => pass,
      :version            => :v2,
      :rackspace_region   => region,
    }
    Fog::Compute.new(opts)
  end

  def self.user_instances(rackspace)
    results = {}

    # Get a list of all the instances, then parse out the tags to see which ones I have created
    instances = rackspace.servers.each do |s|
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
        rackspace = self.connection(user, password)
        instances = self.user_instances(rackspace)
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

  def get_image(images)
    # this is in a method simply because I couldn't figure out how to test it otherwise
    image = images.find {|image| image.name =~ /#{Regexp.escape(resource[:image])}/}
    if image.has_method?('id')
      image.id
    else
      nil
    end
  end

  def get_flavor(flavors)
    # this is in a method simply because I couldn't figure out how to test it otherwise
    flavor = flavors.find {|flavor| flavor.id == resource[:flavor]}
    if flavor.has_method?('id')
      flavor.id
    else
      nil
    end
  end

  def create
    # set the meta used to identify the instance
    meta = {:Name => resource[:name], :CreatedBy => 'Puppet'}

    # create the rackspace connection object
    rackspace = self.class.connection(resource[:user], resource[:pass])

    # search for the image id of the requested image
    images = rackspace.images.find_all
    image_id= get_image(images)

    if image_id

      # search for the flavor to verify it exists
      flavors = rackspace.flavors.find_all
      flavor_id = get_flavor(flavors)

      if flavor_id
        rackspace.servers.create(
          :name      => resource[:name],
          :image_id  => image_id,
          :flavor_id => flavor_id,
          :metadata  => meta
        )
      else
        debug flavors.inspect
        raise Puppet::Error, "the requested flavor was not found"
      end
    else
      debug images.inspect
      raise Puppet::Error, 'the requested image was not found'
    end
  end

  def destroy
    rackspace = self.class.connection(resource[:user], resource[:pass])
    instance = rackspace.servers.get(@property_hash[:id])
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
