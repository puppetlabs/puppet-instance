#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/provider/instance/rackspace'

type_class     = Puppet::Type.type(:instance)
provider_class = type_class.provider(:rackspace)

describe provider_class do

  let(:params_one) {
    {
      :name     => 'one',
      :location => 'ord',
      :flavor   => '2',
      :connection => 'moo',
    }
  }

  let(:params_two) {
    {
      :name       => 'two',
      :location   => 'ord',
      :flavor     => '2',
      :connection => 'moo',
    }
  }

  let(:params_not) {
    {
      :name       => 'not',
      :location   => 'ord',
      :flavor     => '2',
      :connection => 'moo',
    }
  }

  let(:params_connection) {
    {
      :name => 'moo',
      :user => 'user1',
      :pass => 'secret',
    }
  }

  describe "when prefetching" do
    subject { provider_class }

    let (:provider_one) { subject.new(params_one.merge({:provider => subject})) }
    let (:provider_two) { subject.new(params_two.merge({:provider => subject})) }

    let(:resources) do
      [params_one, params_two].inject({}) do |rec, params|
        rec[params[:name]] = type_class.new(params)
        rec
      end
    end

    before do
      subject.stub(:get_instances) {
        {
          "one" => provider_one,
          "two" => provider_two,
        }
      }

      resources['one'].stub(:get_creds) { params_connection }
      resources['two'].stub(:get_creds) { params_connection }
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

end
