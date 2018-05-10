#!/usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/windows/taskscheduler' if Puppet.features.microsoft_windows?
require 'puppet_x/puppetlabs/scheduled_task/taskscheduler2_v1task' if Puppet.features.microsoft_windows?

# These integration tests confirm that the tasks created in a V1 scheduled task APi are visible
# in the V2 API, and that changes in the V2 API will appear in the V1 API.

describe "PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2V1Task", :if => Puppet.features.microsoft_windows? do
  let(:subjectv1) { Win32::TaskScheduler.new() }
  let(:subjectv2) { PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2V1Task }

  context "When created by a V1 API" do
    before(:all) do
      @task_name = 'puppet_task_' + SecureRandom.uuid.to_s

      task = Win32::TaskScheduler.new(@task_name, PuppetX::PuppetLabs::ScheduledTask::Trigger::V1.default_trigger_for('once'))
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
      expect(v2task.trigger(0)).to eq(subjectv1.trigger(0))
    end
  end

  context "When modified by a V2 API" do
    before(:all) do
      @task_name = 'puppet_task_' + SecureRandom.uuid.to_s

      task = Win32::TaskScheduler.new(@task_name, PuppetX::PuppetLabs::ScheduledTask::Trigger::V1.default_trigger_for('once'))
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
      expect(subjectv1.trigger(0)).to eq(v2task.trigger(0))
    end
  end
end
