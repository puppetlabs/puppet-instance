#! /usr/bin/env ruby
require 'spec_helper'

instance = Puppet::Type.type(:instance)

describe instance do
  before do
    @provider = stub 'provider'
    @reousrce = stub 'resource',
      :resource => nil,
      :provider => @provider,
      :ensure   => nil,
      :user     => nil,
      :pass     => nil,
      :flavor   => nil,
      :location => nil,
      :image    => nil
  end
  properties = [:ensure]

  properties.each do |property|
    it "should have a #{property} property" do
      instance.attrclass(property).ancestors.should be_include(Puppet::Property)
    end
  end

  parameters = [:name, :user, :pass, :flavor, :location, :image]

  parameters.each do |parameter|
    it "should have a #{parameter} paramater" do
      instance.attrclass(parameter).ancestors.should be_include(Puppet::Parameter)
    end
  end
end
