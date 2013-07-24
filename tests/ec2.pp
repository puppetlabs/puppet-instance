# Creates two instances in EC2

$region = 'us-west-2'
$zone = 'us-west-2a'

$user = 'xxx'
$pass = 'xxx'

Instance {
  ensure     => present,
  provider   => 'ec2',
  connection => 'aws-west',
  image      => 'ami-e030a5d0',
  flavor     => 't1.micro',
  location   => $zone,
}

cloud_connection { 'aws-west':
  user     => $user,
  pass     => $pass,
  location => $region,
}

instance { "test01": }
instance { "test02": }

