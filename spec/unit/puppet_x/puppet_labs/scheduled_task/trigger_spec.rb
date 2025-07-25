# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/puppet_labs/scheduled_task/trigger'

describe PuppetX::PuppetLabs::ScheduledTask::Trigger do
  subject(:trigger) { described_class }

  describe '#iso8601_datetime_to_local' do
    [nil, ''].each do |value|
      it "returns nil given value '#{value}' (#{value.class})" do
        expect(trigger.iso8601_datetime_to_local(value)).to be_nil
      end
    end

    [
      { input: '2018-01-02T03:04:05', expected: Time.local(2018, 1, 2, 3, 4, 5).getutc },
      { input: '1753-01-01T00:00:00', expected: Time.local(1753, 1, 1, 0, 0, 0).getutc },
      { input: '1899-12-30T00:00:00', expected: Time.local(1899, 12, 30, 0, 0, 0).getutc },
    ].each do |value|
      it "returns a valid Time object for date string #{value[:input]} in the local timezone" do
        converted = trigger.iso8601_datetime_to_local(value[:input])
        expect(converted).to eq(value[:expected])
        expect(converted.to_s).to eq(converted.localtime.to_s)
      end
    end

    [:foo, [], {}].each do |value|
      it "raises ArgumentError given value '#{value}' (#{value.class})" do
        expect { trigger.iso8601_datetime_to_local(value) }.to raise_error(ArgumentError)
      end
    end
  end

  describe PuppetX::PuppetLabs::ScheduledTask::Trigger::Manifest do
    subject(:manifest) { described_class.new }

    describe '#canonicalize_and_validate' do
      [
        {
          # only set required fields
          input: {
            'Enabled' => nil,
            'ScHeDuLe' => 'once',
            'START_date' => '2018-2-3',
            'start_Time' => '1:12',
            'EVERY' => 1,
            'mONTHS' => 12,
            'On' => [1, 'last'],
            'Which_Occurrence' => 'first',
            'DAY_OF_week' => ['mon'],
            'MINutes_intERVAL' => nil,
            'minutes_duration' => nil
          },
          # all keys are lower
          expected: {
            'enabled' => nil,
            'schedule' => 'once',
            'start_date' => '2018-2-3',
            'start_time' => '01:12',
            'every' => 1,
            'months' => [12],
            'on' => [1, 'last'],
            'which_occurrence' => 'first',
            'day_of_week' => ['mon'],
            'minutes_interval' => nil,
            'minutes_duration' => nil
          }
        },
      ].each do |value|
        it "returns downcased keys #{value[:expected]} given a hash with valid case-insensitive keys #{value[:input]}" do
          expect(manifest.class.canonicalize_and_validate(value[:input])).to eq(value[:expected])
        end
      end

      [
        { :foo => nil, 'type' => {} },
        { type: nil },
        { [] => nil },
        { 'type' => [] },
        { 'type' => 1 },
      ].each do |value|
        it "fails with ArgumentError given a hash with invalid keys #{value}" do
          expect { manifest.class.canonicalize_and_validate(value) }.to raise_error(ArgumentError)
        end
      end

      MINIMAL_MANIFEST_HASH =
        {
          'schedule' => 'once',
          'start_date' => '2018-2-3',
          'start_time' => '01:12'
        }.freeze

      it 'canonicalizes `start_date` to %Y-%-m-%-d' do
        manifest_hash = MINIMAL_MANIFEST_HASH.merge('start_date' => '2011-01-02')
        expected = MINIMAL_MANIFEST_HASH.merge('start_date' => '2011-1-2')

        canonical = manifest.class.canonicalize_and_validate(manifest_hash)
        expect(canonical).to eq(expected)
      end

      it 'defaults empty `start_date` to today' do
        manifest_hash = MINIMAL_MANIFEST_HASH.merge('start_date' => '')
        expected = MINIMAL_MANIFEST_HASH.merge('start_date' => Time.now.strftime('%Y-%-m-%-d'))

        canonical = manifest.class.canonicalize_and_validate(manifest_hash)
        expect(canonical).to eq(expected)
      end

      it 'allows nil `start_date`' do
        manifest_hash = MINIMAL_MANIFEST_HASH.merge('schedule' => 'daily',
                                                    'start_date' => nil)
        expected = MINIMAL_MANIFEST_HASH.merge('schedule' => 'daily',
                                               'start_date' => nil)

        canonical = manifest.class.canonicalize_and_validate(manifest_hash)
        expect(canonical).to eq(expected)
      end

      [
        { 'schedule' => 'boot' },
        { 'schedule' => 'logon' },
      ].each do |event_manifest|
        describe 'when validating event based triggers' do
          it 'allows a nil start_time for event based triggers' do
            expect { manifest.class.canonicalize_and_validate(event_manifest) }.not_to raise_error(ArgumentError)
          end

          it 'does not set a default date' do
            validated = manifest.class.canonicalize_and_validate(event_manifest)
            expect(validated).not_to have_key('start_date')
          end
        end
      end

      describe 'when validating user_id for logon triggers' do
        before :each do
          skip('Not on Windows platform') unless Puppet.features.microsoft_windows?
        end

        it 'returns an empty string for user_id if passed an empty string or undef symbol' do
          [
            { 'schedule' => 'logon', 'user_id' => '' },
            { 'schedule' => 'logon', 'user_id' => :undef },
          ].each do |logon_manifest|
            validated = manifest.class.canonicalize_and_validate(logon_manifest)
            expect(validated['user_id']).to eq('')
          end
        end

        it 'does not error if passed a resolvable user_id' do
          logon_manifest = { 'schedule' => 'logon', 'user_id' => 'S-1-5-18' } # Local System Well Known SID
          expect { manifest.class.canonicalize_and_validate(logon_manifest) }.not_to raise_error
        end

        it 'errors if passed an unresolvable user_id' do
          logon_manifest = { 'schedule' => 'logon', 'user_id' => 'Unresolvable UserName' }
          expect { manifest.class.canonicalize_and_validate(logon_manifest) }.to raise_error(ArgumentError)
        end
      end

      describe 'when validating delay and random_delay properties' do
        it 'accepts valid ISO8601 duration format for delay' do
          logon_manifest = { 'schedule' => 'logon', 'delay' => 'PT15M' }
          expect { manifest.class.canonicalize_and_validate(logon_manifest) }.not_to raise_error
        end

        it 'rejects invalid format for delay' do
          logon_manifest = { 'schedule' => 'logon', 'delay' => 'invalid_format' }
          expect { manifest.class.canonicalize_and_validate(logon_manifest) }.to raise_error(ArgumentError, %r{Invalid delay value})
        end

        it 'accepts valid ISO8601 duration format for random_delay' do
          daily_manifest = { 'schedule' => 'daily', 'start_time' => '01:00', 'random_delay' => 'PT15M' }
          expect { manifest.class.canonicalize_and_validate(daily_manifest) }.not_to raise_error
        end

        it 'rejects invalid format for random_delay' do
          daily_manifest = { 'schedule' => 'daily', 'start_time' => '01:00', 'random_delay' => 'invalid_format' }
          expect { manifest.class.canonicalize_and_validate(daily_manifest) }.to raise_error(ArgumentError, %r{Invalid random_delay value})
        end
      end

      it 'canonicalizes `start_time` to %H:%M' do
        manifest_hash = MINIMAL_MANIFEST_HASH.merge('start_time' => '2:03 pm')
        expected = MINIMAL_MANIFEST_HASH.merge('start_time' => '14:03')

        canonical = manifest.class.canonicalize_and_validate(manifest_hash)
        expect(canonical).to eq(expected)
      end

      it 'accepts `minutes_interval` / `minutes_duration` strings and convert to numerics' do
        manifest_hash = MINIMAL_MANIFEST_HASH.merge('minutes_duration' => '15',
                                                    'minutes_interval' => '10')

        expected = MINIMAL_MANIFEST_HASH.merge('minutes_duration' => 15,
                                               'minutes_interval' => 10)

        canonical = manifest.class.canonicalize_and_validate(manifest_hash)
        expect(canonical).to eq(expected)
      end

      it 'canonicalizes `every` to a numeric' do
        manifest_hash = MINIMAL_MANIFEST_HASH.merge('every' => '10')
        expected = MINIMAL_MANIFEST_HASH.merge('every' => 10)

        canonical = manifest.class.canonicalize_and_validate(manifest_hash)
        expect(canonical).to eq(expected)
      end

      it 'canonicalizes `day_of_week` to an array' do
        manifest_hash = MINIMAL_MANIFEST_HASH.merge('day_of_week' => 'mon')
        expected = MINIMAL_MANIFEST_HASH.merge('day_of_week' => ['mon'])

        canonical = manifest.class.canonicalize_and_validate(manifest_hash)
        expect(canonical).to eq(expected)
      end

      it 'canonicalizes `months` to an array' do
        manifest_hash = MINIMAL_MANIFEST_HASH.merge('months' => 1)
        expected = MINIMAL_MANIFEST_HASH.merge('months' => [1])

        canonical = manifest.class.canonicalize_and_validate(manifest_hash)
        expect(canonical).to eq(expected)
      end

      it 'canonicalizes `on` to an array' do
        manifest_hash = MINIMAL_MANIFEST_HASH.merge('on' => 1)
        expected = MINIMAL_MANIFEST_HASH.merge('on' => [1])

        canonical = manifest.class.canonicalize_and_validate(manifest_hash)
        expect(canonical).to eq(expected)
      end

      shared_examples_for 'a trigger that handles start_date and start_time' do
        let(:trigger) do
          manifest.class.canonicalize_and_validate(trigger_hash)
        end

        describe 'the given start_date' do
          before :each do
            trigger_hash['start_time'] = '00:00'
          end

          it 'is able to be specified in ISO 8601 calendar date format' do
            trigger_hash['start_date'] = '2011-12-31'
            expect(trigger['start_date']).to eq('2011-12-31')
          end

          it 'fails if before 1753-01-01' do
            trigger_hash['start_date'] = '1752-12-31'

            expect { trigger['start_date'] }.to raise_error(
              'start_date must be on or after 1753-1-1',
            )
          end

          it 'succeeds if on 1753-01-01' do
            trigger_hash['start_date'] = '1753-01-01'
            expect(trigger['start_date']).to eq('1753-1-1')
          end

          it 'succeeds if after 1753-01-01' do
            trigger_hash['start_date'] = '1753-01-02'
            expect(trigger['start_date']).to eq('1753-1-2')
          end
        end

        describe 'the given start_time' do
          before :each do
            trigger_hash['start_date'] = '2011-12-31'
          end

          it 'is able to be specified as a 24-hour "hh:mm"' do
            trigger_hash['start_time'] = '17:13'
            expect(trigger['start_time']).to eq('17:13')
          end

          it 'is able to be specified as a 12-hour "hh:mm am"' do
            trigger_hash['start_time'] = '3:13 am'
            expect(trigger['start_time']).to eq('03:13')
          end

          it 'is able to be specified as a 12-hour "hh:mm pm"' do
            trigger_hash['start_time'] = '3:13 pm'
            expect(trigger['start_time']).to eq('15:13')
          end
        end
      end

      describe 'when converting a manifest hash' do
        let(:puppet_trigger) do
          {
            'start_date' => '2011-1-1',
            'start_time' => '01:10'
          }
        end
        let(:trigger) do
          manifest.class.canonicalize_and_validate(puppet_trigger)
        end

        context 'working with repeat every x triggers' do
          before :each do
            puppet_trigger['schedule'] = 'once'
          end

          it 'succeeds if minutes_interval is equal to 0' do
            puppet_trigger['minutes_interval'] = '0'

            expect(trigger['minutes_interval']).to eq(0)
          end

          it 'defaults minutes_duration to a full day when minutes_interval is greater than 0 without setting minutes_duration' do
            puppet_trigger['minutes_interval'] = '1'

            expect(trigger['minutes_duration']).to eq(1440)
          end

          it 'succeeds if minutes_interval is greater than 0 and minutes_duration is also set' do
            puppet_trigger['minutes_interval'] = '1'
            puppet_trigger['minutes_duration'] = '2'

            expect(trigger['minutes_interval']).to eq(1)
          end

          it 'fails if minutes_interval is less than 0' do
            puppet_trigger['minutes_interval'] = '-1'

            expect { trigger }.to raise_error(
              'minutes_interval must be an integer greater or equal to 0',
            )
          end

          it 'fails if minutes_interval is not an integer' do
            puppet_trigger['minutes_interval'] = 'abc'
            expect { trigger }.to raise_error(ArgumentError)
          end

          it 'succeeds if minutes_duration is equal to 0' do
            puppet_trigger['minutes_duration'] = '0'
            expect(trigger['minutes_duration']).to eq(0)
          end

          it 'succeeds if minutes_duration is greater than 0' do
            puppet_trigger['minutes_duration'] = '1'
            expect(trigger['minutes_duration']).to eq(1)
          end

          it 'fails if minutes_duration is less than 0' do
            puppet_trigger['minutes_duration'] = '-1'

            expect { trigger }.to raise_error(
              'minutes_duration must be an integer greater than minutes_interval and equal to or greater than 0',
            )
          end

          it 'fails if minutes_duration is not an integer' do
            puppet_trigger['minutes_duration'] = 'abc'
            expect { trigger }.to raise_error(ArgumentError)
          end

          it 'succeeds if minutes_duration is equal to a full day' do
            puppet_trigger['minutes_duration'] = '1440'
            expect(trigger['minutes_duration']).to eq(1440)
          end

          it 'succeeds if minutes_duration is equal to three days' do
            puppet_trigger['minutes_duration'] = '4320'
            expect(trigger['minutes_duration']).to eq(4320)
          end

          it 'succeeds if minutes_duration is greater than minutes_duration' do
            puppet_trigger['minutes_interval'] = '10'
            puppet_trigger['minutes_duration'] = '11'

            expect(trigger['minutes_interval']).to eq(10)
            expect(trigger['minutes_duration']).to eq(11)
          end

          it 'fails if minutes_duration is equal to minutes_interval' do
            # On Windows 2003, the duration must be greater than the interval
            # on other platforms the values can be equal.
            puppet_trigger['minutes_interval'] = '10'
            puppet_trigger['minutes_duration'] = '10'

            expect { trigger }.to raise_error(
              'minutes_duration must be an integer greater than minutes_interval and equal to or greater than 0',
            )
          end

          it 'succeeds if minutes_duration and minutes_interval are both set to 0' do
            puppet_trigger['minutes_interval'] = '0'
            puppet_trigger['minutes_duration'] = '0'

            expect(trigger['minutes_interval']).to eq(0)
            expect(trigger['minutes_duration']).to eq(0)
          end

          it 'fails if minutes_duration is less than minutes_interval' do
            puppet_trigger['minutes_interval'] = '10'
            puppet_trigger['minutes_duration'] = '9'

            expect { trigger }.to raise_error(
              'minutes_duration must be an integer greater than minutes_interval and equal to or greater than 0',
            )
          end

          it 'fails if minutes_duration is less than minutes_interval and set to 0' do
            puppet_trigger['minutes_interval'] = '10'
            puppet_trigger['minutes_duration'] = '0'

            expect { trigger }.to raise_error(
              'minutes_interval cannot be set without minutes_duration also being set to a number greater than 0',
            )
          end
        end

        describe 'when given a one-time trigger' do
          before :each do
            puppet_trigger['schedule'] = 'once'
          end

          it 'sets the schedule to \'once\'' do
            expect(trigger['schedule']).to eq('once')
          end

          it 'does not set a type' do
            expect(trigger).not_to be_has_key('type')
          end

          it "requires 'start_date'" do
            puppet_trigger.delete('start_date')

            expect { trigger }.to raise_error(
              %r{Must specify 'start_date' when defining a one-time trigger},
            )
          end

          it "requires 'start_time'" do
            puppet_trigger.delete('start_time')

            expect { trigger }.to raise_error(
              %r{Must specify 'start_time' when defining a trigger},
            )
          end

          it_behaves_like 'a trigger that handles start_date and start_time' do
            let(:trigger_hash) { { 'schedule' => 'once' } }
          end
        end

        describe 'when given a daily trigger' do
          before :each do
            puppet_trigger['schedule'] = 'daily'
          end

          it "defaults 'every' to 1" do
            pending("canonicalize_and_validate does not set defaults for 'every' or triggers_same? would fail")
            expect(trigger['every']).to eq(1)
          end

          it "uses the specified value for 'every'" do
            puppet_trigger['every'] = 5

            expect(trigger['every']).to eq(5)
          end

          it "defaults 'start_date' to 'today'" do
            pending("canonicalize_and_validate does not set defaults for 'start_date' or triggers_same? would fail")
            puppet_trigger.delete('start_date')
            expect(trigger['start_date']).to eq(Time.now.strftime('%Y-%-m-%-d'))
          end

          it_behaves_like 'a trigger that handles start_date and start_time' do
            let(:trigger_hash) { { 'schedule' => 'daily', 'every' => 1 } }
          end
        end

        describe 'when given a weekly trigger' do
          before :each do
            puppet_trigger['schedule'] = 'weekly'
          end

          it "defaults 'every' to 1" do
            pending("canonicalize_and_validate does not set defaults for 'every' or triggers_same? would fail")
            expect(trigger['every']).to eq(1)
          end

          it "uses the specified value for 'every'" do
            puppet_trigger['every'] = 4

            expect(trigger['every']).to eq(4)
          end

          it "defaults 'day_of_week' to be every day of the week" do
            pending("canonicalize_and_validate does not set defaults for 'day_of_week' or triggers_same? would fail")
            v2 = PuppetX::PuppetLabs::ScheduledTask::Trigger::V2
            expect(trigger['day_of_week']).to eq(v2::Day.names)
          end

          it "uses the specified value for 'day_of_week'" do
            puppet_trigger['day_of_week'] = ['mon', 'wed', 'fri']

            expect(trigger['day_of_week']).to eq(['mon', 'wed', 'fri'])
          end

          it "defaults 'start_date' to 'today'" do
            pending("canonicalize_and_validate does not set defaults for 'start_date' or triggers_same? would fail")
            puppet_trigger.delete('start_date')
            expect(trigger['start_date']).to eq(Time.now.strftime('%Y-%-m-%-d'))
          end

          it_behaves_like 'a trigger that handles start_date and start_time' do
            let(:trigger_hash) { { 'schedule' => 'weekly', 'every' => 1, 'day_of_week' => 'mon' } }
          end
        end

        shared_examples_for 'a monthly schedule' do
          it "defaults 'months' to be every month" do
            pending("canonicalize_and_validate does not set defaults for 'months' or triggers_same? would fail")
            v2 = PuppetX::PuppetLabs::ScheduledTask::Trigger::V2
            expect(trigger['months']).to eq(v2::Month.indexes)
          end

          it "uses the specified value for 'months'" do
            puppet_trigger['months'] = [2, 8]

            expect(trigger['months']).to eq([2, 8])
          end
        end

        describe 'when given a monthly date-based trigger' do
          before :each do
            puppet_trigger['schedule'] = 'monthly'
            puppet_trigger['on']       = [7, 14]
          end

          it_behaves_like 'a monthly schedule'

          it "does not allow 'which_occurrence' to be specified" do
            puppet_trigger['which_occurrence'] = 'first'

            expect { trigger }.to raise_error(
              %r{Neither 'day_of_week' nor 'which_occurrence' can be specified when creating a monthly date-based trigger},
            )
          end

          it "does not allow 'day_of_week' to be specified" do
            puppet_trigger['day_of_week'] = 'mon'

            expect { trigger }.to raise_error(
              %r{Neither 'day_of_week' nor 'which_occurrence' can be specified when creating a monthly date-based trigger},
            )
          end

          it "requires 'on'" do
            puppet_trigger.delete('on')

            expect { trigger }.to raise_error(
              %r{Don't know how to create a 'monthly' schedule with the options: schedule, start_date, start_time},
            )
          end

          it "defaults 'start_date' to 'today'" do
            pending("canonicalize_and_validate does not set defaults for 'start_date' or triggers_same? would fail")
            puppet_trigger.delete('start_date')
            expect(trigger['start_date']).to eq(Time.now.strftime('%Y-%-m-%-d'))
          end

          it_behaves_like 'a trigger that handles start_date and start_time' do
            let(:trigger_hash) { { 'schedule' => 'monthly', 'months' => 1, 'on' => 1 } }
          end
        end

        describe 'when given a monthly day-of-week-based trigger' do
          before :each do
            puppet_trigger['schedule']         = 'monthly'
            puppet_trigger['which_occurrence'] = 'first'
            puppet_trigger['day_of_week']      = 'mon'
          end

          it_behaves_like 'a monthly schedule'

          it "does not allow 'on' to be specified" do
            puppet_trigger['on'] = 15

            expect { trigger }.to raise_error(
              %r{Neither 'day_of_week' nor 'which_occurrence' can be specified when creating a monthly date-based trigger},
            )
          end

          it "requires 'which_occurrence'" do
            puppet_trigger.delete('which_occurrence')

            expect { trigger }.to raise_error(
              %r{which_occurrence must be specified when creating a monthly day-of-week based trigger},
            )
          end

          it "requires 'day_of_week'" do
            puppet_trigger.delete('day_of_week')

            expect { trigger }.to raise_error(
              %r{day_of_week must be specified when creating a monthly day-of-week based trigger},
            )
          end

          it "defaults 'start_date' to 'today'" do
            pending("canonicalize_and_validate does not set defaults for 'start_date' or triggers_same? would fail")
            puppet_trigger.delete('start_date')
            expect(trigger['start_date']).to eq(Time.now.strftime('%Y-%-m-%-d'))
          end

          it_behaves_like 'a trigger that handles start_date and start_time' do
            let(:trigger_hash) { { 'schedule' => 'monthly', 'months' => 1, 'which_occurrence' => 'first', 'day_of_week' => 'mon' } }
          end
        end
      end
    end
  end

  describe PuppetX::PuppetLabs::ScheduledTask::Trigger::Duration do
    subject(:trigger_duration) { described_class.new }

    DAYS_IN_YEAR = 365.2422
    SECONDS_IN_HOUR = 60 * 60
    SECONDS_IN_DAY = 24 * SECONDS_IN_HOUR

    EXPECTED_CONVERSIONS =
      [
        {
          duration: 'P1M4DT2H5M',
          duration_hash: {
            year: nil,
            month: '1',
            day: '4',
            minute: '5',
            hour: '2',
            second: nil
          },
          expected_seconds: (DAYS_IN_YEAR / 12 * SECONDS_IN_DAY) + (4 * SECONDS_IN_DAY) + (5 * 60) + (2 * SECONDS_IN_HOUR)
        },
        {
          duration: 'PT20M',
          duration_hash: {
            year: nil,
            month: nil,
            day: nil,
            minute: '20',
            hour: nil,
            second: nil
          },
          expected_seconds: 20 * 60
        },
        {
          duration: 'P1Y2M30DT12H60M60S',
          duration_hash: {
            year: '1',
            month: '2',
            day: '30',
            minute: '60',
            hour: '12',
            second: '60'
          },
          expected_seconds: (DAYS_IN_YEAR * SECONDS_IN_DAY) + ((DAYS_IN_YEAR / 12 * 2) * SECONDS_IN_DAY) + (30 * SECONDS_IN_DAY) + (60 * 60) + (SECONDS_IN_HOUR * 12) + 60
        },
      ].freeze

    describe '#to_hash' do
      EXPECTED_CONVERSIONS.each do |conversion|
        it "creates expected hashes from duration string #{conversion[:duration]}" do
          expect(trigger_duration.class.to_hash(conversion[:duration])).to eq(conversion[:duration_hash])
        end
      end

      [
        'ABC',
        '123',
      ]
        .each do |duration|
        it "returns nil when failing to parse duration string #{duration}" do
          expect(trigger_duration.class.to_hash(duration)).to be_nil
        end
      end
    end

    describe '#hash_to_seconds' do
      it 'returns 0 for a nil value' do
        expect(trigger_duration.class.hash_to_seconds(nil)).to be_zero
      end

      EXPECTED_CONVERSIONS.each do |conversion|
        rounded_seconds = conversion[:expected_seconds].to_i
        it "returns #{rounded_seconds} seconds given a duration hash" do
          converted = trigger_duration.class.hash_to_seconds(conversion[:duration_hash])
          expect(converted).to eq(rounded_seconds)
        end
      end
    end

    describe '#to_minutes' do
      it 'returns 0 for a nil value' do
        expect(trigger_duration.class.to_minutes(nil)).to be_zero
      end

      it 'returns 0 for an empty string value' do
        expect(trigger_duration.class.to_minutes('')).to be_zero
      end

      [1234, '0', 999.999].each do |value|
        it "returns 0 for the #{value.class} value: #{value}" do
          expect(trigger_duration.class.to_minutes(value)).to be_zero
        end
      end

      EXPECTED_CONVERSIONS.each do |conversion|
        expected_minutes = conversion[:expected_seconds].to_i / 60
        it "returns #{expected_minutes} minutes given a duration #{conversion[:duration]}" do
          converted = trigger_duration.class.to_minutes(conversion[:duration])
          expect(converted).to eq(expected_minutes)
        end
      end
    end
  end

  describe PuppetX::PuppetLabs::ScheduledTask::Trigger::V2::Day do
    subject(:day) { described_class.new }

    # 7 bits for 7 days
    ALL_DAY_SET = 0b1111111

    EXPECTED_DAY_CONVERSIONS =
      [
        { days: 'sun', bitmask: 0b1 },
        { days: [], bitmask: 0 },
        { days: ['mon'], bitmask: 0b10 },
        { days: ['sun', 'sat'], bitmask: 0b1000001 },
        {
          days: ['sun', 'mon', 'tues', 'wed', 'thurs', 'fri', 'sat'],
          bitmask: ALL_DAY_SET
        },
      ].freeze

    describe '#names_to_bitmask' do
      EXPECTED_DAY_CONVERSIONS.each do |conversion|
        it "creates expected bitmask #{'%08b' % conversion[:bitmask]} from days #{conversion[:days]}" do
          expect(day.class.names_to_bitmask(conversion[:days])).to eq(conversion[:bitmask])
        end
      end

      [nil, 1, {}, 'foo', ['bar']].each do |value|
        it "raises an error with invalid value: #{value}" do
          expect { day.class.names_to_bitmask(value) }.to raise_error(ArgumentError)
        end
      end
    end

    describe '#bitmask_to_names' do
      EXPECTED_DAY_CONVERSIONS.each do |conversion|
        it "creates expected days #{conversion[:days]} from bitmask #{'%08b' % conversion[:bitmask]}" do
          expect(day.class.bitmask_to_names(conversion[:bitmask])).to eq([conversion[:days]].flatten)
        end
      end

      [nil, {}, ['bar']].each do |value|
        it "raises an error with invalid value: #{value}" do # rubocop:disable RSpec/RepeatedDescription
          expect { day.class.bitmask_to_names(value) }.to raise_error(TypeError)
        end
      end

      [-1, 'foo', ALL_DAY_SET + 1].each do |value|
        it "raises an error with invalid value: #{value}" do # rubocop:disable RSpec/RepeatedDescription
          expect { day.class.bitmask_to_names(value) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe PuppetX::PuppetLabs::ScheduledTask::Trigger::V2::Days do
    subject(:days) { described_class.new }

    # 31 bits for 31 days
    ALL_NUMERIC_DAYS_SET = 0b01111111111111111111111111111111

    EXPECTED_DAYS_CONVERSIONS =
      [
        { days: 1,                       bitmask: 0b00000000000000000000000000000001, LastDayOfMonth: false },
        { days: [],                      bitmask: 0, LastDayOfMonth: false },
        { days: [2],                     bitmask: 0b00000000000000000000000000000010, LastDayOfMonth: false },
        { days: [3, 5, 8, 12],           bitmask: 0b00000000000000000000100010010100, LastDayOfMonth: false },
        { days: [3, 5, 8, 12, 'last'],   bitmask: 0b00000000000000000000100010010100, LastDayOfMonth: true },
        { days: (1..31).to_a,            bitmask: ALL_NUMERIC_DAYS_SET, LastDayOfMonth: false },
        { days: (1..31).to_a + ['last'], bitmask: ALL_NUMERIC_DAYS_SET, LastDayOfMonth: true },
        # equivalent representations
        { days: 'last',                  bitmask: 0b00000000000000000000000000000000, LastDayOfMonth: true },
        { days: ['last'],                bitmask: 0b00000000000000000000000000000000, LastDayOfMonth: true },
        { days: [1, 'last'],             bitmask: 0b00000000000000000000000000000001, LastDayOfMonth: true },
        { days: [1, 30, 31, 'last'],     bitmask: 0b01100000000000000000000000000001, LastDayOfMonth: true },
      ].freeze

    describe '#indexes_to_bitmask' do
      EXPECTED_DAYS_CONVERSIONS.each do |conversion|
        it "creates expected bitmask #{'%32b' % conversion[:bitmask]} from days #{conversion[:days]}" do
          expect(days.class.indexes_to_bitmask(conversion[:days])).to eq(conversion[:bitmask])
        end
      end

      [nil, {}].each do |value|
        it "raises a TypeError with value: #{value}" do
          expect { days.class.indexes_to_bitmask(value) }.to raise_error(TypeError)
        end
      end

      [-1, 0x1000, [33]].each do |value|
        it "raises an ArgumentError with value: #{value}" do
          expect { days.class.indexes_to_bitmask(value) }.to raise_error(ArgumentError)
        end
      end
    end

    describe '#bitmask_to_indexes' do
      EXPECTED_DAYS_CONVERSIONS.each do |conversion|
        it "creates expected days #{conversion[:days]} from bitmask #{'%32b' % conversion[:bitmask]}" do
          expect(days.class.bitmask_to_indexes(conversion[:bitmask], conversion[:LastDayOfMonth])).to eq([conversion[:days]].flatten)
        end
      end

      [nil, {}, ['bar']].each do |value|
        it "raises a TypeError with value: #{value}" do
          expect { days.class.bitmask_to_indexes(value) }.to raise_error(TypeError)
        end
      end

      it "raises an ArgumentError with value: #{ALL_NUMERIC_DAYS_SET + 1}" do
        expect { days.class.bitmask_to_indexes(ALL_NUMERIC_DAYS_SET + 1) }.to raise_error(ArgumentError)
      end
    end

    describe '#last_day_of_month?' do
      EXPECTED_DAYS_CONVERSIONS.each do |conversion|
        it "returns #{conversion[:LastDayOfMonth]} from days #{conversion[:days]}" do
          expect(days.class.last_day_of_month?(conversion[:days])).to eq(conversion[:LastDayOfMonth])
        end
      end

      [[1, 3, 'first'], [1, 3, 'last', 'first']].each do |value|
        it "returns an ArgumentError for days #{value}" do
          expect { days.class.last_day_of_month?(value) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe PuppetX::PuppetLabs::ScheduledTask::Trigger::V2::Month do
    subject(:month) { described_class.new }

    # 12 bits for 12 months
    ALL_MONTHS_SET = 0b111111111111

    EXPECTED_MONTH_CONVERSIONS =
      [
        { months: 1,            bitmask: 0b000000000001 },
        { months: [1],          bitmask: 0b000000000001 },
        { months: [],           bitmask: 0 },
        { months: [1, 2],       bitmask: 0b000000000011 },
        { months: [1, 12],      bitmask: 0b100000000001 },
        { months: (1..12).to_a, bitmask: ALL_MONTHS_SET },
      ].freeze

    describe '#indexes_to_bitmask' do
      EXPECTED_MONTH_CONVERSIONS.each do |conversion|
        it "creates expected bitmask #{'%12b' % conversion[:bitmask]} from months #{conversion[:months]}" do
          expect(month.class.indexes_to_bitmask(conversion[:months])).to eq(conversion[:bitmask])
        end
      end

      [nil, 13, [13], {}, 'foo', ['bar']].each do |value|
        it "raises an error with invalid value: #{value}" do
          expect { month.class.indexes_to_bitmask(value) }.to raise_error(ArgumentError)
        end
      end
    end

    describe '#bitmask_to_indexes' do
      EXPECTED_MONTH_CONVERSIONS.each do |conversion|
        it "creates expected months #{conversion[:months]} from bitmask #{'%08b' % conversion[:bitmask]}" do
          expect(month.class.bitmask_to_indexes(conversion[:bitmask])).to eq([conversion[:months]].flatten)
        end
      end
    end

    [nil, [13], {}, ['bar']].each do |value|
      it "raises a TypeError with value: #{value}" do
        expect { month.class.bitmask_to_indexes(value) }.to raise_error(TypeError)
      end
    end

    ['foo', -1, ALL_MONTHS_SET + 1].each do |value|
      it "raises an ArgumentError with value: #{value}" do
        expect { month.class.bitmask_to_indexes(value) }.to raise_error(ArgumentError)
      end
    end
  end

  describe PuppetX::PuppetLabs::ScheduledTask::Trigger::V2::WeeksOfMonth do
    subject(:weeks_of_month) { described_class.new }

    ALL_WEEKS_OF_MONTH_SET = 0b11111

    EXPECTED_WEEKS_OF_MONTH_CONVERSIONS =
      [
        { weeks: 'first', bitmask: 0b1 },
        { weeks: [], bitmask: 0 },
        { weeks: ['first'], bitmask: 0b1 },
        { weeks: ['fourth', 'last'], bitmask: 0b11000 },
        {
          weeks: ['first', 'second', 'third', 'fourth', 'last'],
          bitmask: ALL_WEEKS_OF_MONTH_SET
        },
      ].freeze

    describe '#names_to_bitmask' do
      EXPECTED_WEEKS_OF_MONTH_CONVERSIONS.each do |conversion|
        it "creates expected bitmask #{'%08b' % conversion[:bitmask]} from weeks #{conversion[:weeks]}" do
          expect(weeks_of_month.class.names_to_bitmask(conversion[:weeks])).to eq(conversion[:bitmask])
        end
      end

      [nil, 1, {}, 'foo', ['bar']].each do |value|
        it "raises an error with invalid value: #{value}" do
          expect { weeks_of_month.class.names_to_bitmask(value) }.to raise_error(ArgumentError)
        end
      end
    end

    describe '#bitmask_to_names' do
      EXPECTED_WEEKS_OF_MONTH_CONVERSIONS.each do |conversion|
        it "creates expected weeks #{conversion[:weeks]} from bitmask #{'%08b' % conversion[:bitmask]}" do
          expect(weeks_of_month.class.bitmask_to_names(conversion[:bitmask])).to eq([conversion[:weeks]].flatten)
        end
      end

      [nil, {}, ['bar']].each do |value|
        it "raises an error with invalid value: #{value}" do # rubocop:disable RSpec/RepeatedDescription
          expect { weeks_of_month.class.bitmask_to_names(value) }.to raise_error(TypeError)
        end
      end

      [-1, 'foo', ALL_WEEKS_OF_MONTH_SET + 1].each do |value|
        it "raises an error with invalid value: #{value}" do # rubocop:disable RSpec/RepeatedDescription
          expect { weeks_of_month.class.bitmask_to_names(value) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe PuppetX::PuppetLabs::ScheduledTask::Trigger::V2 do
    subject(:v2_class) { described_class.new }

    v2 = described_class
    describe '#to_manifest_hash' do
      DEFAULT_V2_ITRIGGER_PROPERTIES = {
        Id: '',
        Repetition: { Interval: '', Duration: '', StopAtDurationEnd: false },
        ExecutionTimeLimit: '',
        StartBoundary: '',
        EndBoundary: '',
        Enabled: true
      }.freeze

      [
        { Type: v2::Type::TASK_TRIGGER_TIME,
          RandomDelay: '' },
        { Type: v2::Type::TASK_TRIGGER_DAILY,
          DaysInterval: 1,
          RandomDelay: '' },
        { Type: v2::Type::TASK_TRIGGER_WEEKLY,
          DaysOfWeek: 0,
          WeeksInterval: 1,
          RandomDelay: '' },
        { Type: v2::Type::TASK_TRIGGER_MONTHLY,
          DaysOfMonth: 0,
          MonthsOfYear: 4095,
          RunOnLastDayOfMonth: false,
          RandomDelay: '' },
        { Type: v2::Type::TASK_TRIGGER_MONTHLYDOW,
          DaysOfWeek: 1,
          WeeksOfMonth: 1,
          MonthsOfYear: 1,
          RunOnLastWeekOfMonth: false,
          RandomDelay: '' },
      ].each do |trigger_details|
        it "converts a default #{v2::TYPE_MANIFEST_MAP[trigger_details[:Type]]}" do
          i_trigger = DEFAULT_V2_ITRIGGER_PROPERTIES.merge(trigger_details)
          i_trigger[:Repetition] = OpenStruct.new(i_trigger[:Repetition])
          i_trigger = OpenStruct.new(i_trigger)
          allow(i_trigger).to receive(:ole_respond_to?).with('RandomDelay').and_return(true)
          allow(i_trigger).to receive(:ole_respond_to?).with('Delay').and_return(true)
          expect(v2_class.class.to_manifest_hash(i_trigger)).not_to be_nil
        end
      end

      [
        { ole_type: 'IBootTrigger', Type: v2::Type::TASK_TRIGGER_BOOT },
        { ole_type: 'ILogonTrigger', Type: v2::Type::TASK_TRIGGER_LOGON },
      ].each do |trigger_details|
        it "converts an #{trigger_details[:ole_type]} instance" do
          i_trigger = OpenStruct.new(DEFAULT_V2_ITRIGGER_PROPERTIES.merge(trigger_details))
          allow(i_trigger).to receive(:ole_respond_to?).with('RandomDelay').and_return(true)
          expect { v2_class.class.to_manifest_hash(i_trigger) }.not_to raise_error(ArgumentError)
        end
      end

      [
        { ole_type: 'IIdleTrigger', Type: v2::Type::TASK_TRIGGER_IDLE },
        { ole_type: 'IRegistrationTrigger', Type: v2::Type::TASK_TRIGGER_REGISTRATION },
        { ole_type: 'ISessionStateChangeTrigger', Type: v2::Type::TASK_TRIGGER_SESSION_STATE_CHANGE },
        { ole_type: 'IEventTrigger', Type: v2::Type::TASK_TRIGGER_EVENT },
      ].each do |trigger_details|
        it "fails to convert an #{trigger_details[:ole_type]} instance" do
          i_trigger = OpenStruct.new(DEFAULT_V2_ITRIGGER_PROPERTIES.merge(trigger_details))
          allow(i_trigger).to receive(:ole_respond_to?).with('RandomDelay').and_return(true)
          allow(i_trigger).to receive(:ole_respond_to?).with('Delay').and_return(true)
          expect { v2_class.class.to_manifest_hash(i_trigger) }.to raise_error(ArgumentError)
        end
      end

      FILLED_V2_ITRIGGER_PROPERTIES = {
        Id: '1',
        Repetition: { Interval: 'PT20M', Duration: 'PT20M', StopAtDurationEnd: false },
        ExecutionTimeLimit: 'P1M4DT2H5M',
        # StartBoundary is usually specified in local time without TZ
        StartBoundary: "2005-10-11T13:21:17#{Time.local(2005, 10, 11, 13, 21, 17).to_datetime.zone}",
        EndBoundary: '2005-10-11T13:21:17Z',
        Enabled: true
      }.freeze

      # manifest specifies dates / times as local time
      CONVERTED_V2_MANIFEST_HASH = {
        'start_date' => '2005-10-11',
        'start_time' => '13:21',
        'enabled' => true,
        'minutes_interval' => 20, # PT20M
        'minutes_duration' => 20 # PT20M
      }.freeze

      [
        {
          i_trigger: {
            Type: v2::Type::TASK_TRIGGER_TIME,
            RandomDelay: 'P2DT5S' # ignored
          },
          expected: {
            'schedule' => 'once',
            'disable_time_zone_synchronization' => false,
            'random_delay' => 'P2DT5S'
          }
        },
        {
          i_trigger: {
            Type: v2::Type::TASK_TRIGGER_DAILY,
            DaysInterval: 2,
            RandomDelay: 'P2DT5S' # ignored
          },
          expected: {
            'schedule' => 'daily',
            'every' => 2,
            'disable_time_zone_synchronization' => false,
            'random_delay' => 'P2DT5S'
          }
        },
        {
          i_trigger: {
            Type: v2::Type::TASK_TRIGGER_WEEKLY,
            DaysOfWeek: 0b1111111,
            WeeksInterval: 2,
            RandomDelay: 'P2DT5S' # ignored
          },
          expected: {
            'schedule' => 'weekly',
            'every' => 2,
            'day_of_week' => ['sun', 'mon', 'tues', 'wed', 'thurs', 'fri', 'sat'],
            'disable_time_zone_synchronization' => false,
            'random_delay' => 'P2DT5S'
          }
        },
        {
          i_trigger: {
            Type: v2::Type::TASK_TRIGGER_MONTHLY,
            DaysOfMonth: 0b01111111111111111111111111111111,
            MonthsOfYear: 1,
            RunOnLastDayOfMonth: true,
            RandomDelay: 'P2DT5S' # ignored
          },
          expected: {
            'schedule' => 'monthly',
            'months' => [1],
            'on' => (1..31).to_a + ['last'],
            'disable_time_zone_synchronization' => false,
            'random_delay' => 'P2DT5S'
          }
        },
        {
          i_trigger: {
            Type: v2::Type::TASK_TRIGGER_MONTHLYDOW,
            DaysOfWeek: 0b1111111,
            # HACK: choose only the last week selected for test conversion, as this LOSES information
            WeeksOfMonth: 0b10000,
            MonthsOfYear: 0b111111111111,
            RunOnLastWeekOfMonth: true,
            RandomDelay: 'P2DT5S' # ignored
          },
          expected: {
            'schedule' => 'monthly',
            'months' => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
            'which_occurrence' => 'last',
            'day_of_week' => ['sun', 'mon', 'tues', 'wed', 'thurs', 'fri', 'sat'],
            'disable_time_zone_synchronization' => false,
            'random_delay' => 'P2DT5S'
          }
        },
      ].each do |trigger_details|
        it "converts a full ITrigger type #{v2::TYPE_MANIFEST_MAP[trigger_details[:i_trigger][:Type]]} to the equivalent V1 hash" do
          i_trigger = FILLED_V2_ITRIGGER_PROPERTIES.merge(trigger_details[:i_trigger])
          i_trigger[:Repetition] = OpenStruct.new(i_trigger[:Repetition])
          i_trigger = OpenStruct.new(i_trigger)
          allow(i_trigger).to receive(:ole_respond_to?).with('RandomDelay').and_return(true)
          allow(i_trigger).to receive(:ole_respond_to?).with('Delay').and_return(true)
          converted = CONVERTED_V2_MANIFEST_HASH.merge(trigger_details[:expected])
          expect(v2_class.class.to_manifest_hash(i_trigger)).to eq(converted)
        end
      end
    end
  end
end
