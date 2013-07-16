#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/provider/instance/ec2'

type_class     = Puppet::Type.type(:instance)
provider_class = type_class.provider(:ec2)

describe provider_class do

  let(:params_one) {
    {
      :name     => 'one',
      :user     => '111',
      :pass     => '111',
      :location => 'us-west-2',
      :flavor   => 't1.micro',
    }
  }

  let(:params_two) {
    {
      :name     => 'two',
      :user     => '222',
      :pass     => '222',
      :location => 'us-west-2',
      :flavor   => 't1.micro',
    }
  }

  let(:params_not) {
    {
      :name     => 'not',
      :user     => 'not',
      :pass     => 'not',
      :location => 'us-west-2',
      :flavor   => 't1.micro',
    }
  }

  #let(:resource) do
  #  type_class.new.new(:params_one)
  #  )
  #end

  #let (:provider) { resource.provider }

  describe "when prefetching" do
    subject { provider_class }

    let (:provider_one) { subject.new(params_one.merge({:provider => subject})) }
    let (:provider_two) { subject.new(params_two.merge({:provider => subject})) }

    before do
      subject.stub(:get_instances) {
        {
          "one" => provider_one,
          "two" => provider_two,
        }
      }
    end

    let(:resources) do
      [params_one, params_two].inject({}) do |rec, params|
        rec[params[:name]] = type_class.new(params)
        rec
      end
    end

    it "should update resources with existing providers" do
      resources['one'].should_receive(:provider=)
      resources['two'].should_receive(:provider=)

      subject.prefetch(resources)
    end

    it "should not update resources that don't have providers" do
      resources['not'].should_not_receive(:provider=)

      subject.prefetch(resources)
    end
  end

  #context "::create" do
  #  subject { provider_class }
  #  it "should return a Fog::Compute::AWS::Server instance" do
  #    puts provider
  #    puts subject
  #    i = provider.create
  #    i.should be_a_kind_of(Fog::Compute::AWS::Server)
  #  end
  #end

  #context "::destroy" do
  #  it "should return 'shutting-down' when destroying an instance" do
  #    i = provider.create
  #    i.destroy
  #    i.reload
  #    expect(i.state).to eq("shutting-down")
  #  end
  #end

end
