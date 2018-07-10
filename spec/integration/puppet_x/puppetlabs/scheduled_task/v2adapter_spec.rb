#!/usr/bin/env ruby
require 'spec_helper'

require 'puppet_x/puppetlabs/scheduled_task/v2adapter'

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

def manifest_triggers
  now = Time.now

  defaults = {
    'minutes_interval'        => 0,
    'minutes_duration'        => 0,
    'start_date'              => PuppetX::PuppetLabs::ScheduledTask::Trigger::Manifest.format_date(now),
    'start_time'              => PuppetX::PuppetLabs::ScheduledTask::Trigger::Manifest.format_time(now),
    'enabled'                 => true,
  }

  [
    defaults.merge({
      'schedule' => 'once',
    }),
    defaults.merge({
      'schedule' => 'daily',
      'every'    => 1,
    }),
    defaults.merge({
      'schedule'    => 'weekly',
      'every'       => 1,
      'day_of_week' => ['mon'],
    }),
    defaults.merge({
      'schedule'  => 'monthly',
      'months'    => [1],
      'on'        => [14],
    }),
    defaults.merge({
      'schedule'         => 'monthly',
      'months'           => [1],
      'which_occurrence' => 'first',
      'day_of_week'      => ['mon'],
    })
  ]
end

# These integration tests use V2 API tasks and make sure they save
# and read back correctly
describe "PuppetX::PuppetLabs::ScheduledTask::V2Adapter", :if => Puppet.features.microsoft_windows? do
  subject = PuppetX::PuppetLabs::ScheduledTask::V2Adapter

  context "should ignore unknown Trigger types" do
    v2 = PuppetX::PuppetLabs::ScheduledTask::Trigger::V2
    [
      { :ole_type => 'IIdleTrigger', :Type => v2::Type::TASK_TRIGGER_IDLE, },
      { :ole_type => 'IRegistrationTrigger', :Type => v2::Type::TASK_TRIGGER_REGISTRATION, },
      { :ole_type => 'ILogonTrigger', :Type => v2::Type::TASK_TRIGGER_LOGON, },
      { :ole_type => 'ISessionStateChangeTrigger', :Type => v2::Type::TASK_TRIGGER_SESSION_STATE_CHANGE, },
      { :ole_type => 'IEventTrigger', :Type => v2::Type::TASK_TRIGGER_EVENT, },
    ].each do |trigger_details|
      it "by returning nil for a #{trigger_details[:ole_type]} instance" do
        task_object = subject.new('foo')
        # guarantee task not saved to system
        task_object.stubs(:save)
        task_object.expects(:trigger_at).with(1).returns(stub(trigger_details))

        expect(task_object.trigger(0)).to be_nil
      end
    end
  end

  context "should be able to create trigger" do
    before(:all) do
      @task_name = 'puppet_task_' + SecureRandom.uuid.to_s

      task = subject.new(@task_name)
      task.application_name = 'cmd.exe'
      task.parameters = '/c exit 0'
      task.save
    end

    after(:all) do
      subject.delete(@task_name) if subject.exists?(@task_name)
    end

    it "and return the same application_name and properties as those originally set" do
      expect(subject).to be_exists(@task_name)

      task = subject.new(@task_name)
      # verify initial task configuration
      expect(task.parameters).to eq('/c exit 0')
      expect(task.application_name).to eq('cmd.exe')
    end

    manifest_triggers.each do |manifest_hash|
      after(:each) do
        task = subject.new(@task_name)
        1.upto(task.trigger_count).each { |i| task.delete_trigger(0) }
        task.save
      end

      it "#{manifest_hash['schedule']} and return the same properties as those set" do
        # verifying task exists guarantees that .new below loads existing task
        expect(subject).to be_exists(@task_name)

        # append the trigger of given type
        task = subject.new(@task_name)
        task.append_trigger(manifest_hash)
        task.save

        # reload a new task object by name
        task = subject.new(@task_name)

        # trigger specific validation
        expect(task.trigger_count).to eq(1)
        expect(task.trigger(0)).to eq(manifest_hash)
      end
    end
  end

  context "When managing a task" do
    before(:each) do
      @task_name = 'puppet_task_' + SecureRandom.uuid.to_s
      task = subject.new(@task_name)
      task.append_trigger(manifest_triggers[0])
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
      new_trigger = manifest_triggers[0].merge({
        'start_date' => '2112-12-12'
      })

      task = subject.new(@task_name)
      expect(task.delete_trigger(0)).to be(1)
      task.append_trigger(new_trigger)
      task.save
      ps_cmd = '([string]((Get-ScheduledTask | ? { $_.TaskName -eq \'' + @task_name + '\' }).Triggers.StartBoundary) -split \'T\')[0]'
      expect('2112-12-12').to be_same_as_powershell_command(ps_cmd)
    end

    it 'should be able to update a command' do
      new_application_name = 'notepad.exe'
      ps_cmd = '[string]((Get-ScheduledTask | ? { $_.TaskName -eq \'' + @task_name + '\' }).Actions[0].Execute)'
      task = subject.new(@task_name)

      expect('cmd.exe').to be_same_as_powershell_command(ps_cmd)
      task.application_name = new_application_name
      task.save
      expect(new_application_name).to be_same_as_powershell_command(ps_cmd)
    end

    it 'should be able to update command parameters' do
      new_parameters = '/nonsense /utter /nonsense'
      ps_cmd = '[string]((Get-ScheduledTask | ? { $_.TaskName -eq \'' + @task_name + '\' }).Actions[0].Arguments)'
      task = subject.new(@task_name)

      expect('/c exit 0').to be_same_as_powershell_command(ps_cmd)
      task.parameters = new_parameters
      task.save
      expect(new_parameters).to be_same_as_powershell_command(ps_cmd)
    end

    it 'should be able to update the working directory' do
      new_working_directory = 'C:\Somewhere'
      ps_cmd = '[string]((Get-ScheduledTask | ? { $_.TaskName -eq \'' + @task_name + '\' }).Actions[0].WorkingDirectory)'
      task = subject.new(@task_name)

      expect('').to be_same_as_powershell_command(ps_cmd)
      task.working_directory = new_working_directory
      task.save
      expect(new_working_directory).to be_same_as_powershell_command(ps_cmd)
    end
  end
end
