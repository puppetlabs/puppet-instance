#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/provider/instance/ec2'

provider_class = Puppet::Type.type(:instance).provider(:ec2)

describe provider_class do

  before :all do

  end

  let(:name) { 'test01' }
  let(:ec2) { 'ec2' }

  let(:resource) do
    Puppet::Type.type(:instance).new(
      :name     => name,
      :provider => ec2,
      :user     => '03LT76nOvVp4dxMbon9B',
      :pass     => 'RoALhcMiRFb5m2WkqkoyPg4BMSI5LEf7uG0RRnWG',
      :location => 'us-west-2',
      :flavor   => 't1.micro',
    )
  end

  let (:provider) { resource.provider }

  context "::instances" do
    it "should error when the instances method is called" do
      expect { provider.class.instances }.to raise_error Puppet::Error, /username and password/
    end
  end

  context "::prefetch" do
    it "should raise an error when passed an argument other than a hash" do
      expect { provider.class.prefetch(String.new) }.to raise_error Puppet::Error, /resources must be a hash/
    end
  end

  context "::create" do
    it "should return a Fog::Compute::AWS::Server instance" do
      i = provider.create
      i.should be_a_kind_of(Fog::Compute::AWS::Server)
    end
  end

  context "::destroy" do
    it "should return 'shutting-down' when destroying an instance" do
      i = provider.create
      i.destroy
      i.reload
      expect(i.state).to eq("shutting-down")
    end
  end

end
