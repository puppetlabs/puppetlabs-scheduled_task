#!/usr/bin/env ruby
require 'spec_helper'

require_relative '../../../../legacy_taskscheduler' if Puppet.features.microsoft_windows?
require 'puppet_x/puppetlabs/scheduled_task/taskscheduler2' # for TaskScheduler2::ROOT_FOLDER
require 'puppet_x/puppetlabs/scheduled_task/v1adapter'

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

def create_task(task_name = nil, task_compatiblity = nil, triggers = [])
  task_name = 'puppet_task_' + SecureRandom.uuid.to_s if task_name.nil?

  task = PuppetX::PuppetLabs::ScheduledTask::V1Adapter.new(task_name, task_compatiblity)
  task.application_name = 'cmd.exe'
  task.parameters = '/c exit 0'
  triggers.each { |trigger| task.append_trigger(trigger) }
  task.save

  return task, task_name
end

# These integration tests use V2 API tasks and make sure they save
# and read back correctly
describe "When directly calling Scheduled Tasks API v2", :if => Puppet.features.microsoft_windows? do
  subject = PuppetX::PuppetLabs::ScheduledTask::V1Adapter

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

  describe '#enum_task_names' do
    before(:all) do
      # Need a V1 task as a test fixture
      _, @task_name = create_task(nil, :v1_compatibility, [ manifest_triggers[0] ])
    end

    after(:all) do
      subject.delete(@task_name)
    end

    it 'should return all tasks by default' do
      subject_count = subject.enum_task_names.count
      ps_cmd = '(Get-ScheduledTask | Measure-Object).count'
      expect(subject_count).to be_same_as_powershell_command(ps_cmd)
    end

    it 'should not recurse folders if specified' do
      subject_count = subject.enum_task_names(PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::ROOT_FOLDER, { :include_child_folders => false}).count
      ps_cmd = '(Get-ScheduledTask | ? { $_.TaskPath -eq \'\\\' } | Measure-Object).count'
      expect(subject_count).to be_same_as_powershell_command(ps_cmd)
    end

    it 'should only return compatible tasks if specified' do
      compatibility = [PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_COMPATIBILITY::TASK_COMPATIBILITY_V1]
      subject_count = subject.enum_task_names(PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::ROOT_FOLDER, { :include_compatibility => compatibility}).count
      ps_cmd = '(Get-ScheduledTask | ? { [Int]$_.Settings.Compatibility -eq 1 } | Measure-Object).count'
      expect(subject_count).to be_same_as_powershell_command(ps_cmd)
    end
  end

  context "should be able to create trigger" do
    before(:all) do
      _, @task_name = create_task
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
      _, @task_name = create_task(nil, nil, [ manifest_triggers[0] ])
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

  manifest_hash['start_date'] = PuppetX::PuppetLabs::ScheduledTask::Trigger::Manifest.format_date(local_trigger_date)
  manifest_hash['start_time'] = PuppetX::PuppetLabs::ScheduledTask::Trigger::Manifest.format_time(local_trigger_date)
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383618(v=vs.85).aspx
  manifest_hash['enabled']    = v1trigger['flags'] & 0x4 == 0 # TASK_TRIGGER_FLAG_DISABLED
  manifest_hash['minutes_interval'] = v1trigger['minutes_interval'] ||= 0
  manifest_hash['minutes_duration'] = v1trigger['minutes_duration'] ||= 0

  manifest_hash
end

describe "When comparing legacy Puppet Win32::TaskScheduler API v1 to Scheduled Tasks API v2", :if => Puppet.features.microsoft_windows? do
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

  context "When created by the legacy V1 COM API" do
    before(:all) do
      @task_name = 'puppet_task_' + SecureRandom.uuid.to_s

      task = Win32::TaskScheduler.new(@task_name, default_once_trigger)
      task.application_name = 'cmd.exe'
      task.parameters = '/c exit 0'
      task.flags = Win32::TaskScheduler::TASK_FLAG_DISABLED
      task.save
    end

    after(:all) do
      obj = Win32::TaskScheduler.new()
      obj.delete(@task_name) if obj.exists?(@task_name)
    end

    it 'should be visible by the V2 API' do
      expect(subjectv2.exists?(@task_name)).to be true
    end

    it 'should have a compatibility value of 1' do
      expect(subjectv2.new(@task_name, :v1_compatibility).compatibility).to eq(1)
    end

    it 'should have same properties in the V2 API' do
      subjectv1.activate(@task_name)
      v2task = subjectv2.new(@task_name, :v1_compatibility)

      # flags in Win32::TaskScheduler cover all possible flag values
      # flags in V1Adapter only cover enabled status
      v1_disabled = (subjectv1.flags & Win32::TaskScheduler::TASK_FLAG_DISABLED) == Win32::TaskScheduler::TASK_FLAG_DISABLED
      expect(v2task.enabled).to eq(!v1_disabled)
      expect(v2task.parameters).to eq(subjectv1.parameters)
      expect(v2task.application_name).to eq(subjectv1.application_name)
      expect(v2task.trigger_count).to eq(subjectv1.trigger_count)
      v1manifest_hash = to_manifest_hash(subjectv1.trigger(0))
      expect(v2task.trigger(0)).to eq(v1manifest_hash)
    end
  end

  context "When created by the V2 API" do
    before(:all) do
      # create default task with 0 triggers
      _, @task_name = create_task(nil, :v1_compatibility)
    end

    after(:all) do
      PuppetX::PuppetLabs::ScheduledTask::V1Adapter.delete(@task_name) if PuppetX::PuppetLabs::ScheduledTask::V1Adapter.exists?(@task_name)
    end

    it 'should be visible by the V2 API' do
      expect(subjectv2.exists?(@task_name)).to be true
    end

    it 'should have a compatibility value of 1' do
      expect(subjectv2.new(@task_name, :v1_compatibility).compatibility).to eq(1)
    end

    it 'should have same properties in the V2 API' do
      subjectv1.activate(@task_name)
      v2task = subjectv2.new(@task_name, :v1_compatibility)

      # flags in Win32::TaskScheduler cover all possible flag values
      # flags in V1Adapter only cover enabled status
      v1_disabled = (subjectv1.flags & Win32::TaskScheduler::TASK_FLAG_DISABLED) == Win32::TaskScheduler::TASK_FLAG_DISABLED
      expect(v2task.enabled).to eq(!v1_disabled)
      expect(v2task.parameters).to eq(subjectv1.parameters)
      expect(v2task.application_name).to eq(subjectv1.application_name)
      expect(v2task.trigger_count).to eq(subjectv1.trigger_count)
      # on triggers to actually compare for this test
    end
  end

  context "When modifiying a legacy V1 COM API task using the V2 API" do
    before(:all) do
      @task_name = 'puppet_task_' + SecureRandom.uuid.to_s

      task = Win32::TaskScheduler.new(@task_name, default_once_trigger)
      task.application_name = 'cmd.exe'
      task.parameters = '/c exit 0'
      task.flags = Win32::TaskScheduler::TASK_FLAG_DISABLED
      task.save
    end

    after(:all) do
      obj = Win32::TaskScheduler.new()
      obj.delete(@task_name) if obj.exists?(@task_name)
    end

    it 'should be visible by the V2 API' do
      expect(subjectv2.exists?(@task_name)).to be true
    end

    it 'should have a compatibility value of 1' do
      expect(subjectv2.new(@task_name, :v1_compatibility).compatibility).to eq(1)
    end

    it 'should have same properties in the V1 API' do
      arguments_after = '/c exit 255'
      v2task = subjectv2.new(@task_name, :v1_compatibility)
      v2task.parameters = arguments_after
      v2task.save

      subjectv1.activate(@task_name)

      # flags in Win32::TaskScheduler cover all possible flag values
      # flags in V1Adapter only cover enabled status
      v1_disabled = (subjectv1.flags & Win32::TaskScheduler::TASK_FLAG_DISABLED) == Win32::TaskScheduler::TASK_FLAG_DISABLED
      expect(!v1_disabled).to eq(v2task.enabled)
      expect(subjectv1.parameters).to eq(arguments_after)
      expect(subjectv1.application_name).to eq(v2task.application_name)
      expect(subjectv1.trigger_count).to eq(v2task.trigger_count)
      v1manifest_hash = to_manifest_hash(subjectv1.trigger(0))
      expect(v1manifest_hash).to eq(v2task.trigger(0))
    end
  end
end
