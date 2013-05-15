
Instance {
  provider => rackspace,
  image    => 'Debian 7 (Wheezy)',
  flavor   => '2',
  user     => "****",
  pass     => "****",
  location => "dfw",
  ensure   => absent,
}

instance { "test01": }
instance { "test02": }
instance { "test03": }
instance { "test04": }
instance { "test05": }
