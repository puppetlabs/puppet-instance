require 'fog'
require 'pp'
require 'puppet_x/cloud'
require 'puppet_x/cloud/connection'
require 'puppet_x/cloud/connection/ec2'

include PuppetX::Cloud::Connection
include PuppetX::Cloud::Connection::Ec2

Puppet::Type.type(:instance).provide(:ec2) do

  # How else?
  defaultfor :true => :true

  has_feature :load_balancer_member
  has_feature :sshkey

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

  #
  # Retrieves all properties from the server instance and returns hash
  #
  # Thsi is used in prefetching to collect the properties of the existing
  # instances.  It is also used when creating an instance for collecting the
  # values from a newly created instance so those values end up in teh catalog
  # for searching and retrieval.
  #
  def self.collect_properties_from_server(server)
    result_hash = {
      :name       => server.tags["Name"],
      :ensure     => server.state.to_sym,
      :id         => server.id,
      :ip_address => server.public_ip_address,
      :dns_name   => server.dns_name,
      :flavor     => server.flavor_id,
      :image      => server.image_id,
      :status     => server.state,
    }
    result_hash
  end

  #
  # Given a connection, retrieve all instances that we have created, i.e.
  # matching our "creation tags".
  #
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
        result_hash = collect_properties_from_server(s)

        #
        # It is possible that an instance with the same name exists, but is
        # terminated.  In such a case, we only want to add running or pening
        # nodes to the @property_hash to signal that the nodes is indeed
        # running, or on its way to running.  This will keep us from
        # overwriting the state of a resource by the same title with incorrect
        # state, since by all useful accounts a terminated node does not exist,
        # even if it does.
        #
        if [:running,:pending].include?(result_hash[:ensure])
          results[result_hash[:name]] = new(result_hash)
        end
      end
    end

    if results.size > 0
      return results
    else
      return nil
    end
  end

  #
  # Figure out which instances currently exist.
  #
  # For every username and password combination, search for all instances and
  # match the ones that match our tags.  This helps us weed out the instances
  # that we have created, and those that exist for reasons outside our scope.
  #
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
    set_collected_properties()

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

      # Our tag hash that we use to identify nodes we have created
      tags = {
        :Name      => resource[:name],
        :CreatedBy => 'Puppet'
      }

      # Our parameters from the resource that are used for instance creation
      server_hash = {
        :image_id  => resource[:image],
        :flavor_id => resource[:flavor],
        :tags      => tags
      }
      server_hash[:key_name] = @property_hash[:key_name] if @property_hash[:key_name]
      server_hash[:username] = 'root'

      # Create the instance
      server = @conn.servers.create(server_hash)

      # Add missing collected properties to the @property_hash
      self.class.collect_properties_from_server(server).each {|k,v|
        @property_hash[k] ||= v
      }
    end

    # Register with the load balancer
    if @property_hash[:load_balancer] and @property_hash[:id]
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

    # Set the properties of the resource we care about before we assign the
    # resource to the property_hash.
    set_collected_properties()

    @property_hash = resource.to_hash
  end

  private

  #
  # Given a resource name for the load balancer, retrive the Fog object for the
  # Loadbalancer
  #
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
  # There are a few resoruce properties that are collected paramaters, and is
  # only available in the @property_hash.  We set the resource[:id] here to the
  # value of the collected property, so that other resources may look up the
  # resource by name, and have access to the :id that was discovered as part of
  # the @property_hash creation.
  #
  def set_collected_properties
    set_resource_id()
    set_resource_ip_address()
    set_resource_dns_name()
  end

  def set_resource_id
    if @property_hash[:id]
      resource[:id] ||= @property_hash[:id]
    end
  end

  def set_resource_ip_address
    if @property_hash[:ip_address]
      resource[:ip_address] ||= @property_hash[:ip_address]
    end
  end

  def set_resource_dns_name
    if @property_hash[:dns_name]
      resource[:dns_name] ||= @property_hash[:dns_name]
    end
  end

end
