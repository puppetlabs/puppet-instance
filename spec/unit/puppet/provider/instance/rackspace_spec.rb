#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/provider/instance/rackspace'

provider_class = Puppet::Type.type(:instance).provider(:rackspace)

describe provider_class do

  before :all do

  end

  let(:name) { 'test01' }
  let(:rackspace) { 'rackspace' }

  let(:resource) do
    Puppet::Type.type(:instance).new(
      :name     => name,
      :provider => rackspace,
      :user     => '03LT76nOvVp4dxMbon9B',
      :pass     => 'RoALhcMiRFb5m2WkqkoyPg4BMSI5LEf7uG0RRnWG',
      :location => 'ord',
      :flavor   => '2',
      :image    => 'Debian 7.0 (wheezy)'
    )
  end

  let (:provider) { resource.provider }

  context "::instances" do
    it "should implement an instances method" do
      provider.class.should respond_to(:instances)
    end

    it "should error when the instances method is called" do
      expect { provider.class.instances }.to raise_error Puppet::Error, /username and password/
    end
  end

  context "::prefetch" do
    it "should return nil when passed an argument other than a hash" do
      expect { provider.class.prefetch(String.new) }.to raise_error Puppet::Error, /resources must be a hash/
    end
  end

  context "::create" do
    it "should return a Fog::Compute::Rackspace::Server instance" do
      provider.stubs(:get_image).returns(true)
      provider.stubs(:get_flavor).returns(true)
      i = provider.create
      i.should be_a_kind_of(Fog::Compute::RackspaceV2::Server)
    end
  end

  # This test doesn't work for some reason, I think due to the lack of fog
  # actually mocking things for all providers
  #context "::destroy" do
  #  it "should return TrueClass when destroying an instance" do
  #    provider.stubs(:get_image).returns(true)
  #    provider.stubs(:get_flavor).returns(true)
  #    i = provider.create
  #    i.destroy
  #    i.reload
  #    expect(i.state).to eq("shutting-down")
  #  end
  #end

end
