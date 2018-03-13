#!/usr/bin/env ruby
require 'spec_helper'
require 'puppet_x/puppetlabs/scheduled_task/trigger'

describe "PuppetX::PuppetLabs::ScheduledTask::Trigger", :if => Puppet.features.microsoft_windows? do
  let(:subject) { PuppetX::PuppetLabs::ScheduledTask::Trigger }

  EXPECTED_CONVERSIONS =
  [
    {
      :duration => 'P1M4DT2H5M',
      :duration_hash => {
        :year => nil,
        :month => "1",
        :day => "4",
        :minute => "5",
        :hour => "2",
        :second => nil,
      },
    },
    {
      :duration => 'PT20M',
      :duration_hash => {
        :year => nil,
        :month => nil,
        :day => nil,
        :minute => "20",
        :hour => nil,
        :second => nil,
      },
    },
    {
      :duration => 'P1Y2M30DT12H60M60S',
      :duration_hash => {
        :year => "1",
        :month => "2",
        :day => "30",
        :minute => "60",
        :hour => "12",
        :second => "60",
      },
    },
  ].freeze

  describe '#duration_to_hash' do
    EXPECTED_CONVERSIONS.each do |conversion|
      it "should create expected hashes from duration string #{conversion[:duration]}" do
        expect(subject.duration_to_hash(conversion[:duration])).to eq(conversion[:duration_hash])
      end
    end

    [
      'ABC',
      '123'
    ]
    .each do |duration|
      it "should return nil when failing to parse duration string #{duration}" do
        expect(subject.duration_to_hash(duration)).to be_nil
      end
    end
  end
end
