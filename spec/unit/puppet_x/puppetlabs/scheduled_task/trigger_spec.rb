#!/usr/bin/env ruby
require 'spec_helper'
require 'puppet_x/puppetlabs/scheduled_task/trigger'

V2 = PuppetX::PuppetLabs::ScheduledTask::Trigger::V2

describe PuppetX::PuppetLabs::ScheduledTask::Trigger do
  describe "#iso8601_datetime_to_local" do
    [nil, ''].each do |value|
      it "should return nil given value '#{value}' (#{value.class})" do
        expect(subject.iso8601_datetime_to_local(value)).to eq(nil)
      end
    end

    [
      { :input => '2018-01-02T03:04:05', :expected => Time.local(2018, 1, 2, 3, 4, 5).getutc },
      { :input => '1899-12-30T00:00:00', :expected => Time.local(1899, 12, 30, 0, 0, 0).getutc },
    ].each do |value|
      it "should return a valid Time object for date string #{value[:input]} in the local timezone" do
        converted = subject.iso8601_datetime_to_local(value[:input])
        expect(converted).to eq(value[:expected])
        expect(converted.to_s).to eq(converted.localtime.to_s)
      end
    end

    [:foo, [], {}].each do |value|
      it "should raise ArgumentError given value '#{value}' (#{value.class})" do
        expect { subject.iso8601_datetime_to_local(value) }.to raise_error(ArgumentError)
      end
    end
  end
end

describe PuppetX::PuppetLabs::ScheduledTask::Trigger::V1 do
  describe "#canonicalize_and_validate_manifest" do
    [
      {
        # only set required fields
        :input =>
        {
          'Enabled'             => nil,
          'ScHeDuLe'            => 'once',
          'START_date'          => '2018-2-3',
          'start_Time'          => '1:12',
          'EVERY'               => nil,
          'mONTHS'              => nil,
          'On'                  => nil,
          'Which_Occurrence'    => nil,
          'DAY_OF_week'         => nil,
          'MINutes_intERVAL'    => nil,
          'minutes_duration'    => nil,
        },
        # all keys are lower
        :expected =>
        {
          'enabled'             => nil,
          'schedule'            => 'once',
          'start_date'          => '2018-2-3',
          'start_time'          => '01:12',
          'every'               => nil,
          'months'              => nil,
          'on'                  => nil,
          'which_occurrence'    => nil,
          'day_of_week'         => nil,
          'minutes_interval'    => nil,
          'minutes_duration'    => nil,
        }
      },
    ].each do |value|
      it "should return downcased keys #{value[:expected]} given a hash with valid case-insensitive keys #{value[:input]}" do
        expect(subject.class.canonicalize_and_validate_manifest(value[:input])).to eq(value[:expected])
      end
    end

    [
      { :foo => nil, 'type' => {} },
      { :type => nil },
      { [] => nil },
      { 'type' => [] },
      { 'type' => 1 },
    ].each do |value|
      it "should fail with ArgumentError given a hash with invalid keys #{value}" do
        expect { subject.class.canonicalize_and_validate_manifest(value) }.to raise_error(ArgumentError)
      end
    end

    MINIMAL_MANIFEST_HASH =
    {
      'schedule'            => 'once',
      'start_date'          => '2018-2-3',
      'start_time'          => '01:12',
    }

    it 'should canonicalize `start_date` to %Y-%-m-%-d' do
      manifest_hash = MINIMAL_MANIFEST_HASH.merge({ 'start_date' => '2011-01-02' })
      expected = MINIMAL_MANIFEST_HASH.merge({ 'start_date' => '2011-1-2' })

      canonical = subject.class.canonicalize_and_validate_manifest(manifest_hash)
      expect(canonical).to eq(expected)
    end

    it 'should canonicalize `start_time` to %H:%M' do
      manifest_hash = MINIMAL_MANIFEST_HASH.merge({ 'start_time' => '2:03 pm' })
      expected = MINIMAL_MANIFEST_HASH.merge({ 'start_time' => '14:03' })

      canonical = subject.class.canonicalize_and_validate_manifest(manifest_hash)
      expect(canonical).to eq(expected)
    end

    it 'should accept `minutes_interval` / `minutes_duration` strings and convert to numerics' do
      manifest_hash = MINIMAL_MANIFEST_HASH.merge({
        'minutes_duration'    => '15',
        'minutes_interval'    => '10',
      })

      expected = MINIMAL_MANIFEST_HASH.merge({
        'minutes_duration'    => 15,
        'minutes_interval'    => 10,
      })

      canonical = subject.class.canonicalize_and_validate_manifest(manifest_hash)
      expect(canonical).to eq(expected)
    end
  end

  describe '#to_manifest_hash' do
    [
      'once',
      'daily',
      'weekly',
      'monthly',
    ].each do |type|
      it "should convert a default #{type}" do
        v1trigger = subject.class.default_trigger_for(type)
        expect(subject.class.to_manifest_hash(v1trigger)).to_not be_nil
      end
    end

    it "should fail to convert an unknown trigger type" do
      v1trigger = { 'trigger_type' => 'foo' }
      expect { subject.class.to_manifest_hash(v1trigger) }.to raise_error(ArgumentError)
    end

    # V1 Hash uses local dates / times
    FILLED_V1_HASH = {
      'start_year' => 2005,
      'start_month' => 10,
      'start_day' => 11,
      'end_year' => 2005,
      'end_month' => 10,
      'end_day' => 11,
      'start_hour' => 13,
      'start_minute' => 21,
      'minutes_duration' => 20,
      'minutes_interval' => 20,
      'flags' => PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Flag::TASK_TRIGGER_FLAG_HAS_END_DATE,
      'random_minutes_interval' => 0,
    }

    # manifest specifies dates / times as local time
    CONVERTED_MANIFEST_HASH = {
      'start_date' => '2005-10-11',
      'start_time' => '13:21',
      'enabled'    => true,
      'minutes_interval' => 20,
      'minutes_duration' => 20,
    }.freeze

    [
      {
        :v1trigger =>
        {
          'trigger_type' => :TASK_TIME_TRIGGER_ONCE,
          'type' => { 'once' => nil },
        },
        :expected =>
        {
          'schedule' => 'once',
        }
      },
      {
        :v1trigger =>
        {
          'trigger_type' => :TASK_TIME_TRIGGER_DAILY,
          'type' => { 'days_interval' => 2 },
        },
        :expected =>
        {
          'schedule' => 'daily',
          'every'    => '2',
        }
      },
      {
        :v1trigger =>
        {
          'trigger_type' => :TASK_TIME_TRIGGER_WEEKLY,
          'type' => { 'days_of_week' => 0b1111111, 'weeks_interval' => 2 },
        },
        :expected =>
        {
          'schedule'    => 'weekly',
          'every'       => '2',
          'day_of_week' => ['sun', 'mon', 'tues', 'wed', 'thurs', 'fri', 'sat'],
        }
      },
      {
        :v1trigger =>
        {
          'trigger_type' => :TASK_TIME_TRIGGER_MONTHLYDATE,
          'type' => { 'days' => 0b11111111111111111111111111111111, 'months' => 1 },
        },
        :expected =>
        {
          'schedule' => 'monthly',
          'months'   => [1],
          'on'       => (1..31).to_a + ['last'],
        }
      },
      {
        :v1trigger =>
        {
          'trigger_type' => :TASK_TIME_TRIGGER_MONTHLYDOW,
          'type' => { 'weeks' => 5, 'days_of_week' => 0b1111111, 'months' => 0b111111111111 },
        },
        :expected =>
        {
          'schedule'         => 'monthly',
          'months'           => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
          'which_occurrence' => 'last',
          'day_of_week'      => ['sun', 'mon', 'tues', 'wed', 'thurs', 'fri', 'sat'],
        }
      }
    ].each do |trigger_details|
      it "should convert a full V1 #{trigger_details[:v1trigger]['trigger_type']} to the equivalent manifest hash" do
        v1trigger = FILLED_V1_HASH.merge(trigger_details[:v1trigger])
        converted = CONVERTED_MANIFEST_HASH.merge(trigger_details[:expected])
        expect(subject.class.to_manifest_hash(v1trigger)).to eq(converted)
      end
    end
  end
end

describe PuppetX::PuppetLabs::ScheduledTask::Trigger::Duration do
  DAYS_IN_YEAR = 365.2422
  SECONDS_IN_HOUR = 60 * 60
  SECONDS_IN_DAY = 24 * SECONDS_IN_HOUR

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
      :expected_seconds => (DAYS_IN_YEAR / 12 * SECONDS_IN_DAY) + (4 * SECONDS_IN_DAY) + (5 * 60) + (2 * SECONDS_IN_HOUR),
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
      :expected_seconds => 20 * 60
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
      :expected_seconds => (DAYS_IN_YEAR * SECONDS_IN_DAY) + ((DAYS_IN_YEAR / 12 * 2) * SECONDS_IN_DAY) + (30 * SECONDS_IN_DAY) + (60 * 60) + (SECONDS_IN_HOUR * 12) + 60
    },
  ].freeze

  describe '#to_hash' do
    EXPECTED_CONVERSIONS.each do |conversion|
      it "should create expected hashes from duration string #{conversion[:duration]}" do
        expect(subject.class.to_hash(conversion[:duration])).to eq(conversion[:duration_hash])
      end
    end

    [
      'ABC',
      '123'
    ]
    .each do |duration|
      it "should return nil when failing to parse duration string #{duration}" do
        expect(subject.class.to_hash(duration)).to be_nil
      end
    end
  end

  describe '#hash_to_seconds' do
    it "should return 0 for a nil value" do
      expect(subject.class.hash_to_seconds(nil)).to be_zero
    end

    EXPECTED_CONVERSIONS.each do |conversion|
      rounded_seconds = conversion[:expected_seconds].to_i
      it "should return #{rounded_seconds} seconds given a duration hash" do
        converted = subject.class.hash_to_seconds(conversion[:duration_hash])
        expect(converted).to eq(rounded_seconds)
      end
    end
  end

  describe '#to_minutes' do
    it "should return 0 for a nil value" do
      expect(subject.class.to_minutes(nil)).to be_zero
    end

    it "should return 0 for an empty string value" do
      expect(subject.class.to_minutes('')).to be_zero
    end

    [1234, '0', 999.999].each do |value|
      it "should return 0 for the #{value.class} value: #{value}" do
        expect(subject.class.to_minutes(value)).to be_zero
      end
    end

    EXPECTED_CONVERSIONS.each do |conversion|
      expected_minutes = conversion[:expected_seconds].to_i / 60
      it "should return #{expected_minutes} minutes given a duration #{conversion[:duration]}" do
        converted = subject.class.to_minutes(conversion[:duration])
        expect(converted).to eq(expected_minutes)
      end
    end
  end
end

describe PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Day do
  EXPECTED_DAY_CONVERSIONS =
  [
    { :days => 'sun', :bitmask => 0b1 },
    { :days => [], :bitmask => 0 },
    { :days => ['mon'], :bitmask => 0b10 },
    { :days => ['sun', 'sat'], :bitmask => 0b1000001  },
    {
      :days => ['sun', 'mon', 'tues', 'wed', 'thurs', 'fri', 'sat'],
      :bitmask => 0b1111111
    },
  ].freeze

  describe '#names_to_bitmask' do
    EXPECTED_DAY_CONVERSIONS.each do |conversion|
      it "should create expected bitmask #{'%08b' % conversion[:bitmask]} from days #{conversion[:days]}" do
        expect(subject.class.names_to_bitmask(conversion[:days])).to eq(conversion[:bitmask])
      end
    end

    [ nil, 1, {}, 'foo', ['bar'] ].each do |value|
      it "should raise an error with invalid value: #{value}" do
        expect { subject.class.names_to_bitmask(value) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#bitmask_to_names' do
    EXPECTED_DAY_CONVERSIONS.each do |conversion|
      it "should create expected days #{conversion[:days]} from bitmask #{'%08b' % conversion[:bitmask]}" do
        expect(subject.class.bitmask_to_names(conversion[:bitmask])).to eq([conversion[:days]].flatten)
      end
    end

    [ nil, {}, ['bar'] ].each do |value|
      it "should raise an error with invalid value: #{value}" do
        expect { subject.class.bitmask_to_names(value) }.to raise_error(TypeError)
      end
    end

    [ -1, 'foo', 0b1111111 + 1 ].each do |value|
      it "should raise an error with invalid value: #{value}" do
        expect { subject.class.bitmask_to_names(value) }.to raise_error(ArgumentError)
      end
    end
  end
end

describe PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Days do
  EXPECTED_DAYS_CONVERSIONS =
  [
    { :days => 1,                       :bitmask => 0b00000000000000000000000000000001 },
    { :days => [],                      :bitmask => 0 },
    { :days => [2],                     :bitmask => 0b00000000000000000000000000000010 },
    { :days => [3, 5, 8, 12],           :bitmask => 0b00000000000000000000100010010100 },
    { :days => [3, 5, 8, 12, 'last'],   :bitmask => 0b10000000000000000000100010010100 },
    { :days => (1..31).to_a,            :bitmask => 0b01111111111111111111111111111111 },
    { :days => (1..31).to_a + ['last'], :bitmask => 0b11111111111111111111111111111111 },
    # equivalent representations
    { :days => 'last',                  :bitmask => 0b10000000000000000000000000000000 },
    { :days => ['last'],                :bitmask => 1 << (32-1) },
    { :days => [1, 'last'],             :bitmask => 0b10000000000000000000000000000001 },
    { :days => [1, 30, 31, 'last'],     :bitmask => 0b11100000000000000000000000000001 },
  ].freeze

  describe '#indexes_to_bitmask' do
    EXPECTED_DAYS_CONVERSIONS.each do |conversion|
      it "should create expected bitmask #{'%32b' % conversion[:bitmask]} from days #{conversion[:days]}" do
        expect(subject.class.indexes_to_bitmask(conversion[:days])).to eq(conversion[:bitmask])
      end
    end

    [ nil, {} ].each do |value|
      it "should raise a TypeError with value: #{value}" do
        expect { subject.class.indexes_to_bitmask(value) }.to raise_error(TypeError)
      end
    end

    [ 'foo', ['bar'], -1, 0x1000, [33] ].each do |value|
      it "should raise an ArgumentError with value: #{value}" do
        expect { subject.class.indexes_to_bitmask(value) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#bitmask_to_indexes' do
    EXPECTED_DAYS_CONVERSIONS.each do |conversion|
      it "should create expected days #{conversion[:days]} from bitmask #{'%32b' % conversion[:bitmask]}" do
        expect(subject.class.bitmask_to_indexes(conversion[:bitmask])).to eq([conversion[:days]].flatten)
      end
    end

    [ nil, {}, ['bar'] ].each do |value|
      it "should raise a TypeError with value: #{value}" do
        expect { subject.class.bitmask_to_indexes(value) }.to raise_error(TypeError)
      end
    end

    [ 'foo', -1, 0b11111111111111111111111111111111 + 1 ].each do |value|
      it "should raise an ArgumentError with value: #{value}" do
        expect { subject.class.bitmask_to_indexes(value) }.to raise_error(ArgumentError)
      end
    end
  end
end
describe PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Month do
  EXPECTED_MONTH_CONVERSIONS =
  [
    { :months => 1,            :bitmask => 0b000000000001 },
    { :months => [1],          :bitmask => 0b000000000001 },
    { :months => [],           :bitmask => 0 },
    { :months => [1, 2],       :bitmask => 0b000000000011 },
    { :months => [1, 12],      :bitmask => 0b100000000001 },
    { :months => (1..12).to_a, :bitmask => 0b111111111111 },
  ].freeze

  describe '#indexes_to_bitmask' do
    EXPECTED_MONTH_CONVERSIONS.each do |conversion|
      it "should create expected bitmask #{'%12b' % conversion[:bitmask]} from months #{conversion[:months]}" do
        expect(subject.class.indexes_to_bitmask(conversion[:months])).to eq(conversion[:bitmask])
      end
    end

    [ nil, 13, [13], {}, 'foo', ['bar'] ].each do |value|
      it "should raise an error with invalid value: #{value}" do
        expect { subject.class.indexes_to_bitmask(value) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#bitmask_to_indexes' do
    EXPECTED_MONTH_CONVERSIONS.each do |conversion|
      it "should create expected months #{conversion[:months]} from bitmask #{'%08b' % conversion[:bitmask]}" do
        expect(subject.class.bitmask_to_indexes(conversion[:bitmask])).to eq([conversion[:months]].flatten)
      end
    end
  end

  [ nil, [13], {}, ['bar'] ].each do |value|
    it "should raise a TypeError with value: #{value}" do
      expect { subject.class.bitmask_to_indexes(value) }.to raise_error(TypeError)
    end
  end

  [ 'foo', -1, 0b111111111111 + 1 ].each do |value|
    it "should raise an ArgumentError with value: #{value}" do
      expect { subject.class.bitmask_to_indexes(value) }.to raise_error(ArgumentError)
    end
  end
end

describe PuppetX::PuppetLabs::ScheduledTask::Trigger::V2::WeeksOfMonth do
  EXPECTED_WEEKS_OF_MONTH_CONVERSIONS =
  [
    { :weeks => 'first', :bitmask => 0b1 },
    { :weeks => [], :bitmask => 0 },
    { :weeks => ['first'], :bitmask => 0b1 },
    { :weeks => ['fourth', 'last'], :bitmask => 0b11000 },
    {
      :weeks => ['first', 'second', 'third', 'fourth', 'last'],
      :bitmask => 0b11111
    },
  ].freeze

  describe '#names_to_bitmask' do
    EXPECTED_WEEKS_OF_MONTH_CONVERSIONS.each do |conversion|
      it "should create expected bitmask #{'%08b' % conversion[:bitmask]} from weeks #{conversion[:weeks]}" do
        expect(subject.class.names_to_bitmask(conversion[:weeks])).to eq(conversion[:bitmask])
      end
    end

    [ nil, 1, {}, 'foo', ['bar'] ].each do |value|
      it "should raise an error with invalid value: #{value}" do
        expect { subject.class.names_to_bitmask(value) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#bitmask_to_names' do
    EXPECTED_WEEKS_OF_MONTH_CONVERSIONS.each do |conversion|
      it "should create expected weeks #{conversion[:weeks]} from bitmask #{'%08b' % conversion[:bitmask]}" do
        expect(subject.class.bitmask_to_names(conversion[:bitmask])).to eq([conversion[:weeks]].flatten)
      end
    end

    [ nil, {}, ['bar'] ].each do |value|
      it "should raise an error with invalid value: #{value}" do
        expect { subject.class.bitmask_to_names(value) }.to raise_error(TypeError)
      end
    end

    [ -1, 'foo', 0b11111 + 1 ].each do |value|
      it "should raise an error with invalid value: #{value}" do
        expect { subject.class.bitmask_to_names(value) }.to raise_error(ArgumentError)
      end
    end
  end
end

describe PuppetX::PuppetLabs::ScheduledTask::Trigger::V2 do
  describe '#to_manifest_hash' do
    DEFAULT_V2_ITRIGGER_PROPERTIES = {
      :Id                 => '',
      :Repetition         => { :Interval => '', :Duration => '', :StopAtDurationEnd => false },
      :ExecutionTimeLimit => '',
      :StartBoundary      => '',
      :EndBoundary        => '',
      :Enabled            => true,
    }.freeze

    [
      { :Type => V2::Type::TASK_TRIGGER_TIME,
        :RandomDelay  => '',
       },
      { :Type => V2::Type::TASK_TRIGGER_DAILY,
        :DaysInterval => 1,
        :RandomDelay  => '',
      },
      { :Type => V2::Type::TASK_TRIGGER_WEEKLY,
        :DaysOfWeek => 0,
        :WeeksInterval => 1,
        :RandomDelay  => '',
      },
      { :Type => V2::Type::TASK_TRIGGER_MONTHLY,
        :DaysOfMonth => 0,
        :MonthsOfYear => 4095,
        :RunOnLastDayOfMonth => false,
        :RandomDelay  => '',
      },
      { :Type => V2::Type::TASK_TRIGGER_MONTHLYDOW,
        :DaysOfWeek => 1,
        :WeeksOfMonth => 1,
        :MonthsOfYear => 1,
        :RunOnLastWeekOfMonth => false,
        :RandomDelay  => '',
      },
    ].each do |trigger_details|
      it "should convert a default #{V2::TYPE_MANIFEST_MAP[trigger_details[:Type]]}" do
        iTrigger = DEFAULT_V2_ITRIGGER_PROPERTIES.merge(trigger_details)
        # stub is not usable outside of specs (like in DEFAULT_V2_ITRIGGER_PROPERTIES)
        iTrigger[:Repetition] = stub(iTrigger[:Repetition])
        iTrigger = stub(iTrigger)
        expect(subject.class.to_manifest_hash(iTrigger)).to_not be_nil
      end
    end

    [
      { :ole_type => 'IBootTrigger', :Type => V2::Type::TASK_TRIGGER_BOOT, },
      { :ole_type => 'IIdleTrigger', :Type => V2::Type::TASK_TRIGGER_IDLE, },
      { :ole_type => 'IRegistrationTrigger', :Type => V2::Type::TASK_TRIGGER_REGISTRATION, },
      { :ole_type => 'ILogonTrigger', :Type => V2::Type::TASK_TRIGGER_LOGON, },
      { :ole_type => 'ISessionStateChangeTrigger', :Type => V2::Type::TASK_TRIGGER_SESSION_STATE_CHANGE, },
      { :ole_type => 'IEventTrigger', :Type => V2::Type::TASK_TRIGGER_EVENT, },
    ].each do |trigger_details|
      it "should fail to convert an #{trigger_details[:ole_type]} instance" do
        # stub is not usable outside of specs (like in DEFAULT_V2_ITRIGGER_PROPERTIES)
        iTrigger = stub(DEFAULT_V2_ITRIGGER_PROPERTIES.merge(trigger_details))
        expect { subject.class.to_manifest_hash(iTrigger) }.to raise_error(ArgumentError)
      end
    end

    FILLED_V2_ITRIGGER_PROPERTIES = {
      :Id                 => '1',
      :Repetition         => { :Interval => 'PT20M', :Duration => 'PT20M', :StopAtDurationEnd => false },
      :ExecutionTimeLimit => 'P1M4DT2H5M',
      # StartBoundary is usually specified in local time without TZ
      :StartBoundary      => '2005-10-11T13:21:17' + Time.local(2005, 10, 11, 13, 21, 17).to_datetime.zone,
      :EndBoundary        => '2005-10-11T13:21:17Z',
      :Enabled            => true,
    }.freeze

    # manifest specifies dates / times as local time
    CONVERTED_V2_MANIFEST_HASH = {
      'start_date' => '2005-10-11',
      'start_time' => '13:21',
      'enabled'    => true,
      'minutes_interval' => 20, # PT20M
      'minutes_duration' => 20, # PT20M
    }.freeze

    [
      {
        :iTrigger =>
        {
          :Type => V2::Type::TASK_TRIGGER_TIME,
          :RandomDelay  => 'P2DT5S', # ignored
        },
        :expected =>
        {
          'schedule' => 'once',
        }
      },
      {
        :iTrigger =>
        {
          :Type => V2::Type::TASK_TRIGGER_DAILY,
          :DaysInterval => 2,
          :RandomDelay  => 'P2DT5S', # ignored
        },
        :expected =>
        {
          'schedule' => 'daily',
          'every'    => '2',
        }
      },
      {
        :iTrigger =>
        {
          :Type => V2::Type::TASK_TRIGGER_WEEKLY,
          :DaysOfWeek => 0b1111111,
          :WeeksInterval => 2,
          :RandomDelay  => 'P2DT5S', # ignored
        },
        :expected =>
        {
          'schedule'    => 'weekly',
          'every'       => '2',
          'day_of_week' => ['sun', 'mon', 'tues', 'wed', 'thurs', 'fri', 'sat'],
        }
      },
      {
        :iTrigger =>
        {
          :Type => V2::Type::TASK_TRIGGER_MONTHLY,
          :DaysOfMonth => 0b11111111111111111111111111111111,
          :MonthsOfYear => 1,
          :RunOnLastDayOfMonth => true, # ignored
          :RandomDelay  => 'P2DT5S', # ignored
        },
        :expected =>
        {
          'schedule' => 'monthly',
          'months'   => [1],
          'on'       => (1..31).to_a + ['last'],
        }
      },
      {
        :iTrigger =>
        {
          :Type => V2::Type::TASK_TRIGGER_MONTHLYDOW,
          :DaysOfWeek => 0b1111111,
          # HACK: choose only the last week selected for test conversion, as this LOSES information
          :WeeksOfMonth => 0b10000,
          :MonthsOfYear => 0b111111111111,
          :RunOnLastWeekOfMonth => true, # ignored
          :RandomDelay  => 'P2DT5S', # ignored
        },
        :expected =>
        {
          'schedule'         => 'monthly',
          'months'           => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
          'which_occurrence' => 'last',
          'day_of_week'      => ['sun', 'mon', 'tues', 'wed', 'thurs', 'fri', 'sat'],
        }
      },
    ].each do |trigger_details|
      it "should convert a full ITrigger type #{V2::TYPE_MANIFEST_MAP[trigger_details[:iTrigger][:Type]]} to the equivalent V1 hash" do
        iTrigger = FILLED_V2_ITRIGGER_PROPERTIES.merge(trigger_details[:iTrigger])
        # stub is not usable outside of specs (like in DEFAULT_V2_ITRIGGER_PROPERTIES)
        iTrigger[:Repetition] = stub(iTrigger[:Repetition])
        iTrigger = stub(iTrigger)
        converted = CONVERTED_V2_MANIFEST_HASH.merge(trigger_details[:expected])
        expect(subject.class.to_manifest_hash(iTrigger)).to eq(converted)
      end
    end
  end
end
