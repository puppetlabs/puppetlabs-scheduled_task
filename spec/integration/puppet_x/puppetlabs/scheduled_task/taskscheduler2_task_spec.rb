#!/usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/windows/taskscheduler' if Puppet.features.microsoft_windows?
require 'puppet_x/puppetlabs/scheduled_task/taskscheduler2_task'
# require 'puppet_x/puppetlabs/scheduled_task/taskscheduler2'

def triggers
  now = Time.now

  defaults = {
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
  }

  [
    # dummy time trigger
    defaults.merge({
      'random_minutes_interval' => 0,
      'trigger_type'            => :TASK_TRIGGER_TIME,
    }),
    defaults.merge({
      # TODO: should this be settable?
      # 'random_minutes_interval' => 1,
      'trigger_type'            => :TASK_TRIGGER_TIME,
    }),
    defaults.merge({
      # TODO: should this be settable?
      # 'random_minutes_interval' => 1,
      'type'                    => { 'days_interval' => 1 },
      'trigger_type'            => :TASK_TRIGGER_DAILY,
    }),
    defaults.merge({
      # TODO: should this be settable?
      # 'random_minutes_interval' => 1,
      'type'         => {
        'weeks_interval' => 1,
        'days_of_week'   => Win32::TaskScheduler::MONDAY,
      },
      'trigger_type'            => :TASK_TRIGGER_WEEKLY,
    }),
    defaults.merge({
      # TODO: should this be settable?
      # 'random_minutes_interval' => 1,
      'type'         => {
        'months' => Win32::TaskScheduler::JANUARY,
        # TODO: this value seems to be cooked up wrong
        # 'days'   => 1 | 1 << 2 | 1 << 4 | 1 << 14 | 1 << 31,
        # 8192 is for the 14th
        'days'   => 8192,
      },
      'trigger_type'            => :TASK_TRIGGER_MONTHLY,
    }),
    defaults.merge({
      # TODO: should this be settable?
      # 'random_minutes_interval' => 1,
      'type'         => {
        'months'       => Win32::TaskScheduler::JANUARY,
        'weeks'        => Win32::TaskScheduler::FIRST_WEEK,
        'days_of_week' => Win32::TaskScheduler::MONDAY,
      },
      'trigger_type'            => :TASK_TRIGGER_MONTHLYDOW,
    })
  ]
end

# These integration tests use V2 API tasks and make sure they save
# and read back correctly
describe PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2Task, :if => Puppet.features.microsoft_windows? do

  triggers.each do |trigger|
    context "should be able to create a #{trigger['trigger_type']} trigger" do
      before(:each) do
        @task_name = 'puppet_task_' + SecureRandom.uuid.to_s

        task = subject.class.new(@task_name, trigger)
        task.application_name = 'cmd.exe'
        task.parameters = '/c exit 0'
        task.save
      end

      # TODO: test each of the currently supported trigger types
      # v2 API is weird and prefers to have '' for RandomDelay for TASK_TRIGGER_TIME
      it 'and should return the same properties as those set' do
        expect(subject.exists?(@task_name)).to be true

        task = subject.activate(@task_name)

        expect(subject.parameters).to eq('/c exit 0')
        expect(subject.application_name).to eq('cmd.exe')
        expect(subject.trigger_count).to eq(1)


        # require 'pry'; binding.pry
        # TODO: need to compare to dummy_trigger
        # require 'pry'; binding.pry
        # expect(subject.trigger(0).Flags).to eq(trigger['flags'])
      end

      after(:each) do
        subject.delete(@task_name) if subject.exists?(@task_name)
      end
    end
  end


  # TODO: this test is kind of pointless right now
  # it 'should be mutable with V2 API' do
  #   arguments_after = '/c exit 255'
  #   subject.activate(@task_name)
  #   subject.parameters = arguments_after
  #   subject.save

  #   expect(subject.flags).to eq(PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::DISA
  #   expect(subject.parameters).to eq(arguments_after)
  #   expect(subject.application_name).to eq('cmd.exe')
  #   expect(subject.trigger_count).to eq(1)
  #   # require 'pry'; binding.pry
  #   # TODO: need to compare to dummy_trigger
  #   expect(subject.trigger(0).Flags).to eq(dummy_time_trigger['flags'])
  # end
end
