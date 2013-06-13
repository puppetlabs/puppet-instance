Puppet::Type.newtype(:instance) do
  @doc = "Instance provisioning with puppet."

  feature :endpoint, "The provider specifies the API endpoint with which to
  create a connection."

  feature :bootable, "The provider has a distinction between creating and
  booting the instance.",
    :methods => [:start,:stop]

  newparam(:name, :namevar => true) do
    desc "unique name of instance"
  end

  newparam(:user) do
    desc "User"
    isrequired
  end

  newparam(:pass, :isrequired => true) do
    desc "Password"
  end

  newparam(:flavor, :required_features => :flavors) do
    desc "Instance flavors, provider dependant."
  end

  newparam(:location) do
    desc "What datacenter/region is this instance in?"
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

  newparam(:pool) do
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

end
