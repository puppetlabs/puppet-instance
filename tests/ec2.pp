
Instance {
  provider => 'ec2',
  image    => 'ami-e030a5d0',
  flavor   => 't1.micro',
  user     => "****",
  pass     => "****",
  location => "us-west-2",
  ensure   => absent,
}

instance { "test01":
}
instance { "test02":
}
