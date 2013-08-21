#instance

##Overview

The Puppet Instance type contains a collection of Puppet providers to work with
and manage the creation and destruction of compute instances for a various of
cloud vendors.

##Module Description

The Compute instances are the core of working in cloud providers, and this
module allows users to define those compute instances using the Puppet DSL.
This includes the ability to define the image the instance should be created
from, the data center, and the size that the instance should be on initial
creation, as well as terminate the instance when it is no longer needed.

Please note that some cloud providers have different features.  The Puppet
instance module does it best to smooth these out, but there is still some
required knowledge of what it means to build infrastructure in one cloud
vendor or another.

##Usage

To create an instance in Ec2, a simple example will do.

    instance { 'test01':
      ensure     => present,
      provider   => 'ec2',
      connection => 'aws-west',
      image      => 'ami-e030a5d0',
      flavor     => 't1.micro',
      location   => 'us-west-2a',
    }

This resource will create an 't1.micro' instance in the 'us-west-2a'
availability zone from the AMI specified at the image.  A few things to note
about this resource.

First, you must know how Amazon refers to their instance "flavors".  These
define the general geometry of a compute node.  This is the disk, cpu, memory,
etc that describe the size of the instance.  This same requisite knowledge is
true for the locations.  Location refers to the Availability Zone, or which
data center the instance should be built in.

Next, the connection is special to the Puppet modules that build infrastructure
components.  The "cloud_connection" puppet module is required for this
parameter.

That module can be found
[here](https://github.com/puppetlabs/puppet-cloud_connection).  Please see the
README for information about the 'cloud_connection' type.  The 'connection'
parameter here is the resource title of the 'cloud_connection' resource that
you wish to use for API calls.

# Copyright

Puppet Labs 2013

# License

Apache 2.0
