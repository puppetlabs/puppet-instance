require 'fog'
require 'pp'

Puppet::Type.type(:instance).provide(:ec2) do

  defaultfor :true => :true

  has_feature :load_balancer_member

  #
  # Connect to AWS
  #
  # Return the Fog::Compute conneciton object
  #
  def self.connection(user,pass,region='us-west-2')
    opts = {
      :provider              => 'aws',
      :aws_access_key_id     => user,
      :aws_secret_access_key => pass,
      :region                => region,
    }

    debug "creating connection to AWS for EC2"
    Fog::Compute.new(opts)
  end

  def self.get_instances(conn)
    debug "matching existing instances to our manifest"
    results = {}

    #
    # Get a list of all the instances, then parse out the tags to see which
    # ones are owned by this user
    #
    conn.servers.each do |s|
      if s.tags["Name"] != nil and s.tags["CreatedBy"] == "Puppet"
        debug s.inspect
        instance_name = s.tags["Name"]
        result_hash = {
          :name   => instance_name,
          :ensure => s.state.to_sym,
          :id     => s.id,
          :flavor => s.flavor_id,
          :image  => s.image_id,
          :status => s.state,
        }
        results[instance_name] = new(result_hash)
      end
    end

    if results.size > 0
      return results
    else
      return nil
    end
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
    @property_hash = resource.to_hash
  end

  def destroy
    connect()
    instance = @conn.servers.get(@property_hash[:id])
    instance.destroy
    @property_hash.clear
  end

  def exists?
    #
    # While I don't like the idea of manipulating the resource in a method that
    # is intended to do nothing but return the state, I need to set the :id of
    # the resource, and since exists? is the only resource method that is
    # guaranteed to be called ( that I know if ) then we set it here so it ends
    # up in the catalog.
    #
    set_resource_id()
    debug "performing existential inquisition: " + @property_hash.inspect
    @property_hash and [:running,:pending].include?(@property_hash[:ensure])
  end

  def load_balancer
    is_load_balancer_member?
  end

  def load_balancer=(value)
    @property_hash[:load_balancer] = value
  end

  def flush
    debug "flushing properties"
    connect()

    # Create the instance
    if [:running,:present].include?(@property_hash[:ensure])
      debug "creating instance #{@property_hash[:name]}"

      tags = {
        :Name => resource[:name],
        :CreatedBy => 'Puppet'
      }
      server_hash = {
        :image_id => resource[:image],
        :flavor_id => resource[:flavor],
        :tags => tags
      }
      server = @conn.servers.create(server_hash)

      @property_hash[:id] = server.id

    end

    # Register with the load balancer
    if @property_hash[:load_balancer]
        if @property_hash[:id]
          debug "Registering instance #{@property_hash[:id]} with #{@property_hash[:load_balancer]}"

          get_cloud_connection()

          args = []
          args << @connection_resource[:user]
          args << @connection_resource[:pass]
          args << @connection_resource[:location] if @connection_resource[:location]

          elb = Puppet::Type::Loadbalancer::ProviderElb.connection(*args)
          elb.register_instances_with_load_balancer(
            @property_hash[:id],
            @property_hash[:load_balancer],
          )
        end
    end
    @property_hash = resource.to_hash
  end

  private

  #
  # Get the connection object using the current resource paramaters
  #
  # Here we just return the existing connection object if it already exists or
  # build it and return it.
  #
  # @conn is the connection object.  It is the fog resource that does the
  # actual lifting.
  #
  def connect
    if @conn
      debug "found existing connection"
      return @conn
    else
      get_cloud_connection()

      debug "exting connection not found"

      args = []
      args << @connection_resource[:user]
      args << @connection_resource[:pass]
      args << @connection_resource[:location] if @connection_resource[:location]

      @conn = self.class.connection(*args)
      return @conn
    end
  end

  #
  # Get the credentials fom the type by searching through the catlog for the
  # given connection resoruce.
  #
  # This is strictly a helper to ensure that we lookup the information only
  # one time..
  #
  def get_cloud_connection
    if @connection_resource
      debug "found connection resource"
      return @connection_resource
    else
      debug "searching for connection resource"
      @connection_resource = resource.get_creds(resource[:connection])
      return @connection_resource
    end
  end

  def get_loadbalancer(name=resource[:load_balancer])
    get_cloud_connection()
    args = []

    args << @connection_resource[:user]
    args << @connection_resource[:pass]
    args << @connection_resource[:location] if @connection_resource[:location]

    @loadbalancer_connection = Puppet::Type::Loadbalancer::ProviderElb.connection(*args)

    load_balancer = @loadbalancer_connection.load_balancers.find {|lb|
      lb.id == name
    }
  end

  #
  # Check to see if the current instance is a member of the load_balancer
  #
  # This requires creating a connection instance for ELB, finding the load
  # balanacer and testing its instances method to see if our current
  # resource[:id] is included.
  #
  # We return the name of the load balancer if true
  #
  # If we are not found, we return false.
  #
  # If the property_hash is empty, then we return nil.
  #
  def is_load_balancer_member?
    debug "checking load balancer membership"

    if @property_hash.size > 0
      connect()

      load_balancer = get_loadbalancer()
      if load_balancer and load_balancer.instances.include?(@property_hash[:id])
        debug "Instance #{@property_hash[:id]} already a member of #{resource[:load_balancer]}"
        return resource[:load_balancer]
      else
        debug "Registering #{@property_hash[:id]} with #{resource[:load_balancer]}"
        return false
      end
    end
    nil
  end

  #
  # The resource 'id' is a collected paramater, and is only available in the
  # @property_hash.  We set the resource[:id] here to the value of the
  # collected property, so that other resources may look up the resource by
  # name, and have access to the :id that was discovered as part of the
  # @property_hash creation.
  #
  def set_resource_id
    if @property_hash[:id]
      resource[:id] ||= @property_hash[:id]
    end
  end
end
