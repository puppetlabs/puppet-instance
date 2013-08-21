require 'puppet_x/cloud/credentials'

include PuppetX::Cloud::Credentials

Puppet::Type.newtype(:instance) do
  @doc = "Instance provisioning with puppet."

  feature :endpoint, "The provider specifies the API endpoint with which to
    create a connection."

  feature :bootable, "The provider has a distinction between creating and
    booting the instance.",
    :methods => [:start,:stop]

  feature :load_balanced, "Used if the provider has support for adding
    instances to load balancers."

  feature :sshkey, "The provider supports building instances with root ssh
    authorized keys configured."

  feature :flavors, "The provider supports instance flavors."

  newparam(:name, :namevar => true) do
    desc "unique name of instance"
  end

  newparam(:connection, :isrequired => true) do
    desc "The connection and credential resource to use for API calls."
  end

  newparam(:flavor, :required_features => :flavors) do
    desc "Instance flavors, provider dependant."
  end

  newparam(:location) do
    desc "The datacenter/region/availability_zone to use."
  end

  newparam(:image, :required => true) do
    desc "The image to deploy.  What this means depends on the provider.  For
      example, in Ec2 image referes to an AMI, in Rackspace its the
      operatingsystem type.  In vSphere, its the path to the template."
  end

  newparam(:endpoint, :required_features => :endpoint) do
    desc "The API endpoint to use for communication"
  end

  newparam(:insecure, :required_features => :endpoint) do
    desc "The insecurity level of endpoint"

    newvalues(:true, :false)

    defaultto :false
  end

  newparam(:id) do
    desc "The ID of the created instance"
    # Collected parameter only.  Do not assign!
  end

  newparam(:ip_address) do
    desc "The IP of the created instance"
    # Collected parameter only.  Do not assign!
  end

  newparam(:dns_name) do
    desc "The IP of the created instance"
    # Collected parameter only.  Do not assign!
  end

  newproperty(:load_balancer, :required_features => :load_balanced) do
    desc "The load balancer to which the instance should be a pool member"
  end

  newparam(:pool) do
    desc "The resource pool the instance should be in"
  end

  newparam(:key_name, :isrequired => true, :required_features => :sshkey) do
  end

  ensurable do
    desc("What state the instance should be in.")

    newvalue(:present, :event => :instance_created) do
      provider.create
    end

    newvalue(:absent, :event => :instance_destroyed) do
      provider.destroy
    end

    newvalue(:running, :event => :instance_booted, :required_features => :bootable) do
      provider.start
    end

    newvalue(:stopped, :event => :instance_stopped, :required_features => :bootable) do
      provider.stop
    end

    defaultto :present
  end

  autorequire(:load_balancer) do
    self[:load_balancer]
  end

  autorequire(:connection) do
    self[:connection]
  end

end
