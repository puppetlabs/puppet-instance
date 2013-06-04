Puppet::Type.newtype(:instance) do
  @doc = "Instance provisioning with puppet."

  feature :endpoint, "The API endpoint to create a connection to."

  ensurable

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

  newparam(:image) do
    isrequired
  end

  newparam(:endpoint, :required_features => :endpoint) do
  end

  newparam(:insecure, :required_features => :endpoint) do
  end

  newparam(:pool) do
  end

end
