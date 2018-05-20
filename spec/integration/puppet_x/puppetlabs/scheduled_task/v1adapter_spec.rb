#!/usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/windows/taskscheduler' if Puppet.features.microsoft_windows?
require 'puppet_x/puppetlabs/scheduled_task/v1adapter'

# These integration tests confirm that the tasks created in a V1 scheduled task APi are visible
# in the V2 API, and that changes in the V2 API will appear in the V1 API.

# originally V1 API support, only used in this spec file now
def to_manifest_hash(v1trigger)
  trigger = PuppetX::PuppetLabs::ScheduledTask::Trigger

  v1_type_map =
  {
    :TASK_TIME_TRIGGER_DAILY => trigger::V2::Type::TASK_TRIGGER_DAILY,
    :TASK_TIME_TRIGGER_WEEKLY => trigger::V2::Type::TASK_TRIGGER_WEEKLY,
    :TASK_TIME_TRIGGER_MONTHLYDATE => trigger::V2::Type::TASK_TRIGGER_MONTHLY,
    :TASK_TIME_TRIGGER_MONTHLYDOW => trigger::V2::Type::TASK_TRIGGER_MONTHLYDOW,
    :TASK_TIME_TRIGGER_ONCE => trigger::V2::Type::TASK_TRIGGER_TIME,
  }.freeze

  unless v1_type_map.keys.include?(v1trigger['trigger_type'])
    raise ArgumentError.new(_("Unknown trigger type %{type}") % { type: v1trigger['trigger_type'] })
  end

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381950(v=vs.85).aspx
  week_of_month_names = {
    'first'  => 1, # TASK_FIRST_WEEKs
    'second' => 2, # TASK_SECOND_WEEKs
    'third'  => 3, # TASK_THIRD_WEEKs
    'fourth' => 4, # TASK_FOURTH_WEEKs
    'last'   => 5, # TASK_LAST_WEEKs
  }.freeze

  manifest_hash = {}

  case v1trigger['trigger_type']
  when :TASK_TIME_TRIGGER_DAILY
    manifest_hash['schedule'] = 'daily'
    manifest_hash['every']    = v1trigger['type']['days_interval'].to_s
  when :TASK_TIME_TRIGGER_WEEKLY
    manifest_hash['schedule']    = 'weekly'
    manifest_hash['every']       = v1trigger['type']['weeks_interval'].to_s
    manifest_hash['day_of_week'] = trigger::V2::Day.bitmask_to_names(v1trigger['type']['days_of_week'])
  when :TASK_TIME_TRIGGER_MONTHLYDATE
    manifest_hash['schedule'] = 'monthly'
    manifest_hash['months']   = trigger::V2::Month.bitmask_to_indexes(v1trigger['type']['months'])
    manifest_hash['on']       = trigger::V2::Days.bitmask_to_indexes(v1trigger['type']['days'])

  when :TASK_TIME_TRIGGER_MONTHLYDOW
    manifest_hash['schedule']         = 'monthly'
    manifest_hash['months']           = trigger::V2::Month.bitmask_to_indexes(v1trigger['type']['months'])
    manifest_hash['which_occurrence'] = week_of_month_names.key(v1trigger['type']['weeks'])
    manifest_hash['day_of_week']      = trigger::V2::Day.bitmask_to_names(v1trigger['type']['days_of_week'])
  when :TASK_TIME_TRIGGER_ONCE
    manifest_hash['schedule'] = 'once'
  end

  # V1 triggers are local time already, same as manifest
  local_trigger_date = Time.local(
    v1trigger['start_year'],
    v1trigger['start_month'],
    v1trigger['start_day'],
    v1trigger['start_hour'],
    v1trigger['start_minute'],
    0
  )

  manifest_hash['start_date'] = local_trigger_date.strftime('%Y-%-m-%-d')
  manifest_hash['start_time'] = local_trigger_date.strftime('%H:%M')
  manifest_hash['enabled']    = v1trigger['flags'] & trigger::V1::Flag::TASK_TRIGGER_FLAG_DISABLED == 0
  manifest_hash['minutes_interval'] = v1trigger['minutes_interval'] ||= 0
  manifest_hash['minutes_duration'] = v1trigger['minutes_duration'] ||= 0

  manifest_hash
end

describe "PuppetX::PuppetLabs::ScheduledTask::V1Adapter", :if => Puppet.features.microsoft_windows? do
  let(:subjectv1) { Win32::TaskScheduler.new() }
  let(:subjectv2) { PuppetX::PuppetLabs::ScheduledTask::V1Adapter }
  now = Time.now
  default_once_trigger =
  {
    'flags'                   => 0,
    'end_day'                 => 0,
    'end_year'                => 0,
    'minutes_interval'        => 0,
    'end_month'               => 0,
    'minutes_duration'        => 0,
    'start_year'              => now.year,
    'start_month'             => now.month,
    'start_day'               => now.day,
    'start_hour'              => now.hour,
    'start_minute'            => now.min,
    'trigger_type'            => :TASK_TIME_TRIGGER_ONCE,
    # 'once' has no specific settings, so 'type' should be omitted
  }

  context "When created by a V1 API" do
    before(:all) do
      @task_name = 'puppet_task_' + SecureRandom.uuid.to_s

      task = Win32::TaskScheduler.new(@task_name, default_once_trigger)
      task.application_name = 'cmd.exe'
      task.parameters = '/c exit 0'
      task.flags = PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_FLAG_DISABLED
      task.save
    end

    after(:all) do
      obj = Win32::TaskScheduler.new()
      obj.delete(@task_name) if obj.exists?(@task_name)
    end

    it 'should be visible by the V2 API' do
      expect(subjectv2.exists?(@task_name)).to be true
    end

    it 'should have same properties in the V2 API' do
      subjectv1.activate(@task_name)
      v2task = subjectv2.new(@task_name)

      expect(v2task.flags).to eq(subjectv1.flags)
      expect(v2task.parameters).to eq(subjectv1.parameters)
      expect(v2task.application_name).to eq(subjectv1.application_name)
      expect(v2task.trigger_count).to eq(subjectv1.trigger_count)
      v1manifest_hash = to_manifest_hash(subjectv1.trigger(0))
      expect(v2task.trigger(0)).to eq(v1manifest_hash)
    end
  end

  context "When modified by a V2 API" do
    before(:all) do
      @task_name = 'puppet_task_' + SecureRandom.uuid.to_s

      task = Win32::TaskScheduler.new(@task_name, default_once_trigger)
      task.application_name = 'cmd.exe'
      task.parameters = '/c exit 0'
      task.flags = PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_FLAG_DISABLED
      task.save
    end

    after(:all) do
      obj = Win32::TaskScheduler.new()
      obj.delete(@task_name) if obj.exists?(@task_name)
    end

    it 'should be visible by the V2 API' do
      expect(subjectv2.exists?(@task_name)).to be true
    end

    it 'should have same properties in the V1 API' do
      arguments_after = '/c exit 255'
      v2task = subjectv2.new(@task_name)
      v2task.parameters = arguments_after
      v2task.save

      subjectv1.activate(@task_name)

      expect(subjectv1.flags).to eq(v2task.flags)
      expect(subjectv1.parameters).to eq(arguments_after)
      expect(subjectv1.application_name).to eq(v2task.application_name)
      expect(subjectv1.trigger_count).to eq(v2task.trigger_count)
      v1manifest_hash = to_manifest_hash(subjectv1.trigger(0))
      expect(v1manifest_hash).to eq(v2task.trigger(0))
    end
  end
end
