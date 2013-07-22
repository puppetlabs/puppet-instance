#! /usr/bin/env ruby
require 'spec_helper'

instance = Puppet::Type.type(:instance)

describe instance do

  it "should have an :endpoint feature" do
    instance.provider_feature(:endpoint).should_not be_nil
  end

  it "should have a :bootable feature" do
    instance.provider_feature(:bootable).should_not be_nil
  end

  properties = [:ensure,:load_balancer]
  properties.each do |property|
    it "should have a #{property} property" do
      instance.attrtype(property).should eq(:property)
    end
  end

  parameters = [:name, :connection, :flavor, :location, :image, :endpoint, :insecure, :id, :pool]
  parameters.each do |parameter|
    it "should have a #{parameter} paramater" do
      instance.attrtype(parameter).should eq(:param)
    end
  end
end
