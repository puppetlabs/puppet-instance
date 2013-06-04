class Puppet::Util::Fog

  require 'pp'

  def self.user_instances(compute)
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

end
