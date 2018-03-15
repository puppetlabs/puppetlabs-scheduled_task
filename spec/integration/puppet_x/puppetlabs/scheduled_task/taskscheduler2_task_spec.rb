#!/usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/windows/taskscheduler' if Puppet.features.microsoft_windows?
require 'puppet_x/puppetlabs/scheduled_task/taskscheduler2_task'
# require 'puppet_x/puppetlabs/scheduled_task/taskscheduler2'

RSpec::Matchers.define :be_same_as_powershell_command do |ps_cmd|
  define_method :run_ps do |cmd|
    full_cmd = "powershell.exe -NoLogo -NoProfile -NonInteractive -Command \"#{cmd}\""

    result = `#{full_cmd}`

    result.strip
  end

  match do |actual|
    from_ps = run_ps(ps_cmd)

    # This matcher probably won't tolerate UTF8 characters
    actual.to_s == from_ps
  end

  failure_message do |actual|
    "expected that #{actual} would match #{run_ps(ps_cmd)} from PowerShell command #{ps_cmd}"
  end
end

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
      'random_minutes_interval' => 1,
      'trigger_type'            => :TASK_TRIGGER_TIME,
    }),
    defaults.merge({
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

      after(:each) do
        subject.delete(@task_name) if subject.exists?(@task_name)
      end

      # TODO: test each of the currently supported trigger types
      # v2 API is weird and prefers to have '' for RandomDelay for TASK_TRIGGER_TIME
      it 'and should return the same properties as those set' do
        expect(subject.exists?(@task_name)).to be true

        task = subject.activate(@task_name)

        expect(subject.parameters).to eq('/c exit 0')
        expect(subject.application_name).to eq('cmd.exe')
        expect(subject.trigger_count).to eq(1)
        expect(subject.trigger(0)['trigger_type']).to eq(trigger['trigger_type'])
        expect(subject.trigger(0)['type']).to eq(trigger['type']) if trigger['type']
        expect(task.Definition.Triggers.Item(1).RandomDelay).to eq("PT#{trigger['random_minutes_interval']}M") if trigger['random_minutes_interval']
                
      end
    end
  end

  context "When managing a task" do
    before(:each) do
      @task_name = 'puppet_task_' + SecureRandom.uuid.to_s
      task = subject.class.new(@task_name, triggers[0])
      task.application_name = 'cmd.exe'
      task.parameters = '/c exit 0'
      task.save
    end

    after(:each) do
      subject.delete(@task_name) if subject.exists?(@task_name)
    end

    it 'should be able to determine if the task exists or not' do
      bad_task_name = SecureRandom.uuid.to_s
      expect(subject.exists?(@task_name)).to be(true)
      expect(subject.exists?(bad_task_name)).to be(false)
    end

    it 'should able to update a trigger' do
      new_trigger = triggers[0].merge({
        'start_year'              => 2112,
        'start_month'             => 12,
        'start_day'               => 12,
        'start_hour'              => 12,
        'start_minute'            => 12,
      })

      task = subject.activate(@task_name)
      expect(subject.delete_trigger(0)).to be(1)
      subject.trigger = new_trigger
      subject.save
      ps_cmd = '[string]((Get-ScheduledTask | ? { $_.TaskName -eq \'' + @task_name + '\' }).Triggers.StartBoundary)'
      expect('2112-12-12T12:12:00').to be_same_as_powershell_command(ps_cmd)
    end

    it 'should be able to update a command' do
      new_application_name = 'notepad.exe'
      ps_cmd = '[string]((Get-ScheduledTask | ? { $_.TaskName -eq \'' + @task_name + '\' }).Actions[0].Execute)'
      task = subject.activate(@task_name)

      expect('cmd.exe').to be_same_as_powershell_command(ps_cmd)

      subject.application_name = new_application_name
      subject.save
      
      expect(new_application_name).to be_same_as_powershell_command(ps_cmd)
    end

    it 'should be able to update command parameters' do
      new_parameters = '/nonsense /utter /nonsense'
      ps_cmd = '[string]((Get-ScheduledTask | ? { $_.TaskName -eq \'' + @task_name + '\' }).Actions[0].Arguments)'
      task = subject.activate(@task_name)

      expect('/c exit 0').to be_same_as_powershell_command(ps_cmd)

      subject.parameters = new_parameters
      subject.save
      
      expect(new_parameters).to be_same_as_powershell_command(ps_cmd)
    end

    it 'should be able to update the working directory' do
      new_working_directory = 'C:\Somewhere'
      ps_cmd = '[string]((Get-ScheduledTask | ? { $_.TaskName -eq \'' + @task_name + '\' }).Actions[0].WorkingDirectory)'
      task = subject.activate(@task_name)

      expect('').to be_same_as_powershell_command(ps_cmd)

      subject.working_directory = new_working_directory
      subject.save
      
      expect(new_working_directory).to be_same_as_powershell_command(ps_cmd)
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
