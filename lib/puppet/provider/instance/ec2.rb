require 'fog'
require 'puppet/util/fog'
require 'pp'

Puppet::Type.type(:instance).provide(:ec2) do

  defaultfor :true => :true

  has_feature :load_balancer_member

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

    # Get a list of all the instances, then parse out the tags to see which
    # ones are owned by this uer
    instances = compute.servers.each do |s|
      if s.tags["Name"] != nil and s.tags["CreatedBy"] == "Puppet"
        debug s.inspect
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
    tags = {
      :Name => resource[:name],
      :CreatedBy => 'Puppet'
    }
    ec2 = self.class.connection(resource[:user], resource[:pass])
    server = ec2.servers.create(
      :image_id => resource[:image],
      :flavor_id => resource[:flavor],
      :tags => tags
    )
    @property_hash[:id] = server.id
    debug @property_hash.inspect
    unless resource[:load_balancer].nil?
      ensure_load_balancer_member
    end
  end

  def destroy
    ec2 = self.class.connection(resource[:user], resource[:pass])
    instance = ec2.servers.get(@property_hash[:id])
    instance.destroy
  end

  def exists?
    debug @property_hash.inspect
    @property_hash and [:running,:pending].include?(@property_hash[:ensure])
  end

  def load_balancer
    is_load_balancer_member?
  end

  def load_balancer=(lb)
    if @property_hash[:id]
      elb = Puppet::Type::Loadbalancer::ProviderElb.connection(
        resource[:user],
        resource[:pass],
      )
      elb.register_instances_with_load_balancer(
        @property_hash[:id],
        lb,
      )
    end
    nil
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
    if @property_hash.size > 0
      elb = Puppet::Type::Loadbalancer::ProviderElb.connection(
        resource[:user],
        resource[:pass],
      )
      load_balancer = elb.load_balancers.find {|lb|
        lb.id == resource[:load_balancer]
      }
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

end
