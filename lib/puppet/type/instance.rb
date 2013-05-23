Puppet::Type.newtype(:instance) do
  @doc = "Instance provisioning with puppet."

  ensurable

  newparam(:name, :namevar => true) do
    desc "unique name of instance"
    isnamevar
  end

  newparam(:user) do
    desc "User"
    isrequired
  end

  newparam(:pass) do
    desc "Password"
    isrequired
  end

  newparam(:flavor) do

  end

  newparam(:location) do
    desc "What datacenter/region is this instance in?"
  end

  newparam(:image) do
    isrequired
  end

end
