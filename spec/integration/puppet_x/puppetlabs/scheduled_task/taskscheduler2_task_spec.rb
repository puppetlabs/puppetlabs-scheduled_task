
#!/usr/bin/env ruby
require 'spec_helper'

require 'puppet_x/puppetlabs/scheduled_task/taskscheduler2_task'

RSpec::Matchers.define :be_same_as_powershell_command do |ps_cmd|
  define_method :run_ps do |cmd|
    full_cmd = "powershell.exe -NoLogo -NoProfile -NonInteractive -Command \"#{cmd}\""

    result = `#{full_cmd}`

    result.strip
  end

  match do |actual|
    from_ps = run_ps(ps_cmd)
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
      'trigger_type'            => :TASK_TIME_TRIGGER_ONCE,
    }),
    defaults.merge({
      'type'                    => { 'days_interval' => 1 },
      'trigger_type'            => :TASK_TIME_TRIGGER_DAILY,
    }),
    defaults.merge({
      'type'         => {
        'weeks_interval' => 1,
        'days_of_week'   => PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Day::TASK_MONDAY,
      },
      'trigger_type'            => :TASK_TIME_TRIGGER_WEEKLY,
    }),
    defaults.merge({
      'type'         => {
        'months' => PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Month::TASK_JANUARY,
        # Bitwise mask, reference on MSDN:
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380735(v=vs.85).aspx
        # 8192 is for the 14th
        'days'   => 8192,
      },
      'trigger_type'            => :TASK_TIME_TRIGGER_MONTHLYDATE,
    }),
    defaults.merge({
      'type'         => {
        'months'       => PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Month::TASK_JANUARY,
        'weeks'        => PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Occurrence::TASK_FIRST_WEEK,
        'days_of_week' => PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Day::TASK_MONDAY,
      },
      'trigger_type'            => :TASK_TIME_TRIGGER_MONTHLYDOW,
    })
  ]
end

# These integration tests use V2 API tasks and make sure they save
# and read back correctly
describe "PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2Task", :if => Puppet.features.microsoft_windows? do
  let(:subject) { PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2Task.new() }

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

      it 'and should return the same properties as those set' do
        expect(subject.exists?(@task_name)).to be true

        task = subject.activate(@task_name)

        expect(subject.parameters).to eq('/c exit 0')
        expect(subject.application_name).to eq('cmd.exe')
        expect(subject.trigger_count).to eq(1)
        expect(subject.trigger(0)['trigger_type']).to eq(trigger['trigger_type'])
        expect(subject.trigger(0)['type']).to eq(trigger['type']) if trigger['type']
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
      })

      task = subject.activate(@task_name)
      expect(subject.delete_trigger(0)).to be(1)
      subject.trigger = new_trigger
      subject.save
      ps_cmd = '([string]((Get-ScheduledTask | ? { $_.TaskName -eq \'' + @task_name + '\' }).Triggers.StartBoundary) -split \'T\')[0]'
      expect('2112-12-12').to be_same_as_powershell_command(ps_cmd)
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
end
