#!/usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/windows/taskscheduler' if Puppet.features.microsoft_windows?
require 'puppet_x/puppetlabs/scheduled_task/taskscheduler2_task' if Puppet.features.microsoft_windows?

def dummy_time_trigger
  now = Time.now
  {
    'flags'                   => 0,
    'random_minutes_interval' => 0,
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
    'trigger_type'            => Win32::TaskScheduler::ONCE,
  }
end

# These integration tests confirm that the tasks created in a V1 scheduled task APi are visible
# in the V2 API, and that changes in the V2 API will appear in the V1 API.

describe "PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2Task", :if => Puppet.features.microsoft_windows? do
  let(:subjectv1) { Win32::TaskScheduler.new() }
  let(:subjectv2) { PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2Task.new() }

  context "When created by a V1 API" do
    before(:all) do
      @task_name = 'puppet_task_' + SecureRandom.uuid.to_s

      task = Win32::TaskScheduler.new(@task_name, dummy_time_trigger)
      task.application_name = 'cmd.exe'
      task.parameters = '/c exit 0'
      task.flags = Win32::TaskScheduler::DISABLED
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
      v1task = subjectv1.activate(@task_name)
      v2task = subjectv2.activate(@task_name)

      expect(subjectv2.flags).to eq(subjectv1.flags)
      expect(subjectv2.parameters).to eq(subjectv1.parameters)
      expect(subjectv2.application_name).to eq(subjectv1.application_name)
      expect(subjectv2.trigger_count).to eq(subjectv1.trigger_count)
      expect(subjectv2.trigger(0)).to eq(subjectv1.trigger(0))
    end
  end

  context "When modified by a V2 API" do
    before(:all) do
      @task_name = 'puppet_task_' + SecureRandom.uuid.to_s

      task = Win32::TaskScheduler.new(@task_name, dummy_time_trigger)
      task.application_name = 'cmd.exe'
      task.parameters = '/c exit 0'
      task.flags = Win32::TaskScheduler::DISABLED
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
      subjectv2.activate(@task_name)
      subjectv2.parameters = arguments_after
      subjectv2.save

      subjectv1.activate(@task_name)

      expect(subjectv1.flags).to eq(subjectv2.flags)
      expect(subjectv1.parameters).to eq(arguments_after)
      expect(subjectv1.application_name).to eq(subjectv2.application_name)
      expect(subjectv1.trigger_count).to eq(subjectv2.trigger_count)
      expect(subjectv1.trigger(0)).to eq(subjectv2.trigger(0))
    end
  end
end
