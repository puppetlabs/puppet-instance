require 'fog'
require 'puppet_x/cloud'
#require 'puppet_x/cloud/connection/rackspace'

include PuppetX::Cloud::Connection

Puppet::Type.type(:instance).provide(:rackspace) do

  has_feature :flavors
  has_feature :load_balanced

  def self.connection(user,pass,region='dfw')
    opts = {
      :provider           => 'rackspace',
      :rackspace_username => user,
      :rackspace_api_key  => pass,
      :version            => :v2,
      :rackspace_region   => region,
    }
    debug "creating connection to Rackspace for Instance"
    Fog::Compute.new(opts)
  end

  #
  # Retrieves all properties from the server instance and return hash
  #
  # This is used in prefetching to collect the properties of the existing
  # instances.  It is also used when creating an instance for collecting the
  # values from a newly created instance so those values end up in the catalog
  # for searching and retrieval.
  #
  def self.collect_properties_from_server(server)
    result_hash = {
      :name       => server.metadata["Name"],
      :ensure     => server.state.downcase.to_sym,
      :id         => server.id,
      :ip_address => server.ipv4_address,
      :flavor     => server.flavor_id,
      :image      => server.image_id,
    }
    result_hash
  end

  def self.get_instances(conn)
    debug "matching existing instances to our manifest"
    results = {}

    # Get a list of all the instances, then parse out the tags to see which ones are owned by this uer
    conn.servers.each do |s|
      if s.metadata["Name"] != nil and s.metadata["CreatedBy"] == "Puppet"
        debug s.inspect
        result_hash = collect_properties_from_server(s)

        if [:active,:build].include?(result_hash[:ensure])
          results[result_hash[:name]] = new(result_hash)
        end
      end
    end
    results
  end

  def self.prefetch(resources)
    if resources.is_a? Hash
      resources_by_user = {}
      users = {}

      resources.each do |name, resource|
        connection_resource = resource.get_creds(resource[:connection])
        resources_by_user[connection_resource[:user]] ||= []
        resources_by_user[connection_resource[:user]] << resource
        users[connection_resource[:user]] ||= connection_resource[:pass]
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
    connect()

    # set the meta used to identify the instance
    tags = {:Name => resource[:name], :CreatedBy => 'Puppet'}

    # search for the image id of the requested image
    images = @conn.images.find_all
    image_id= get_image(images)

    if image_id

      # search for the flavor to verify it exists
      flavors = @conn.flavors.find_all
      flavor_id = get_flavor(flavors)

      if flavor_id
        @conn.servers.create(
          :name      => resource[:name],
          :image_id  => image_id,
          :flavor_id => flavor_id,
          :metadata  => tags
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
    connect()
    instance = @conn.servers.get(@property_hash[:id])
    instance.destroy
    @property_hash.clear
  end

  def exists?
    debug @property_hash.inspect
    !(@property_hash[:ensure] == :absent or @property_hash.empty?)
  end

  private

  def get_image(images)
    # this is in a method simply because I couldn't figure out how to test it otherwise
    image = images.find {|image| image.name =~ /#{Regexp.escape(resource[:image])}/}
    if image and image.respond_to?('id')
      image.id
    else
      nil
    end
  end

  def get_flavor(flavors)
    # this is in a method simply because I couldn't figure out how to test it otherwise
    flavor = flavors.find {|flavor| 
      flavor.id == resource[:flavor]
    }
    if flavor and flavor.respond_to?('id')
      flavor.id
    else
      nil
    end
  end


end
