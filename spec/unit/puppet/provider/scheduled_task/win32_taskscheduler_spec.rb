#! /usr/bin/env ruby
require 'spec_helper'

require_relative '../../../../legacy_taskscheduler' if Puppet.features.microsoft_windows?
require 'puppet_x/puppetlabs/scheduled_task/task'

describe Puppet::Type.type(:scheduled_task).provider(:taskscheduler_api2), :if => Puppet.features.microsoft_windows? do
  it 'should be the default provider' do
    expect(Puppet::Type.type(:scheduled_task).defaultprovider).to eq(subject.class)
  end
end

# The win32_taskscheduler and taskscheduler_api2 providers should be API compatible and behave
# the same way.  What differs is which Windows API is used to query and affect the system.
# This means for testing, any tests should be the same no matter what provider or concrete class
# (which the provider uses) is used.
task_providers = Puppet.features.microsoft_windows? ? [:win32_taskscheduler, :taskscheduler_api2] : []
task_providers.each do |task_provider|

task2 = PuppetX::PuppetLabs::ScheduledTask::Task

describe Puppet::Type.type(:scheduled_task).provider(task_provider), :if => Puppet.features.microsoft_windows? do
  before :each do
    Puppet::Type.type(:scheduled_task).stubs(:defaultprovider).returns(described_class)
  end

  describe 'when retrieving' do
    before :each do
      @mock_task = stub
      @mock_task.responds_like_instance_of(task2)
      described_class.any_instance.stubs(:task).returns(@mock_task)

      task2.stubs(:new).returns(@mock_task)
    end
    let(:resource) { Puppet::Type.type(:scheduled_task).new(:name => 'Test Task', :command => 'C:\Windows\System32\notepad.exe') }

    describe 'the triggers for a task' do
      describe 'with only one trigger' do
        it 'should handle a single daily trigger' do
          @mock_task.expects(:triggers).returns([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'daily',
            'every'            => '2',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'daily',
            'every'            => '2',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])
        end

        it 'should handle a single daily with repeat trigger' do
          @mock_task.expects(:triggers).returns([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'daily',
            'every'            => '2',
            'minutes_interval' => 60,
            'minutes_duration' => 180,
            'enabled'          => true,
            'index'            => 0,
          }])

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'daily',
            'every'            => '2',
            'minutes_interval' => 60,
            'minutes_duration' => 180,
            'enabled'          => true,
            'index'            => 0,
          }])
        end

        it 'should handle a single weekly trigger' do
          @mock_task.expects(:triggers).returns([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'weekly',
            'every'            => '2',
            'day_of_week'      => ['sun', 'mon', 'wed', 'fri'],
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'weekly',
            'every'            => '2',
            'day_of_week'      => ['sun', 'mon', 'wed', 'fri'],
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])
        end

        it 'should handle a single monthly date-based trigger' do
          @mock_task.expects(:triggers).returns([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'monthly',
            'months'           => [1, 2, 8, 9, 12],
            'on'               => [1, 3, 5, 15, 'last'],
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'monthly',
            'months'           => [1, 2, 8, 9, 12],
            'on'               => [1, 3, 5, 15, 'last'],
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])
        end

        it 'should handle a single monthly day-of-week-based trigger' do
          @mock_task.expects(:triggers).returns([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'monthly',
            'months'           => [1, 2, 8, 9, 12],
            'which_occurrence' => 'first',
            'day_of_week'      => ['sun', 'mon', 'wed', 'fri'],
            'enabled'          => true,
            'index'            => 0,
          }])

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'monthly',
            'months'           => [1, 2, 8, 9, 12],
            'which_occurrence' => 'first',
            'day_of_week'      => ['sun', 'mon', 'wed', 'fri'],
            'enabled'          => true,
            'index'            => 0,
          }])
        end

        it 'should handle a single one-time trigger' do
          @mock_task.expects(:triggers).returns([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])

          expect(resource.provider.trigger).to eq([{
            'start_date'       => '2011-9-12',
            'start_time'       => '13:20',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          }])
        end
      end

      it 'should handle multiple triggers' do
        @mock_task.expects(:triggers).returns([{
          'start_date'       => '2011-10-13',
          'start_time'       => '14:21',
          'schedule'         => 'once',
          'minutes_interval' => 0,
          'minutes_duration' => 0,
          'enabled'          => true,
          'index'            => 0,
        },
        {
          'start_date'       => '2012-11-14',
          'start_time'       => '15:22',
          'schedule'         => 'once',
          'minutes_interval' => 0,
          'minutes_duration' => 0,
          'enabled'          => true,
          'index'            => 1,
        },
        {
          'start_date'       => '2013-12-15',
          'start_time'       => '16:23',
          'schedule'         => 'once',
          'minutes_interval' => 0,
          'minutes_duration' => 0,
          'enabled'          => true,
          'index'            => 2,
        }])

        expect(resource.provider.trigger).to match_array([
          {
            'start_date'       => '2011-10-13',
            'start_time'       => '14:21',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          },
          {
            'start_date'       => '2012-11-14',
            'start_time'       => '15:22',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 1,
          },
          {
            'start_date'       => '2013-12-15',
            'start_time'       => '16:23',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 2,
          }
        ])
      end

      it 'should handle multiple triggers with repeat triggers' do
        @mock_task.expects(:triggers).returns([{
          'start_date'       => '2011-10-13',
          'start_time'       => '14:21',
          'schedule'         => 'once',
          'minutes_interval' => 15,
          'minutes_duration' => 60,
          'enabled'          => true,
          'index'            => 0,
        },
        {
          'start_date'       => '2012-11-14',
          'start_time'       => '15:22',
          'schedule'         => 'once',
          'minutes_interval' => 30,
          'minutes_duration' => 120,
          'enabled'          => true,
          'index'            => 1,
        },
        {
          'start_date'       => '2013-12-15',
          'start_time'       => '16:23',
          'schedule'         => 'once',
          'minutes_interval' => 60,
          'minutes_duration' => 240,
          'enabled'          => true,
          'index'            => 2,
        }])

        expect(resource.provider.trigger).to match_array([
          {
            'start_date'       => '2011-10-13',
            'start_time'       => '14:21',
            'schedule'         => 'once',
            'minutes_interval' => 15,
            'minutes_duration' => 60,
            'enabled'          => true,
            'index'            => 0,
          },
          {
            'start_date'       => '2012-11-14',
            'start_time'       => '15:22',
            'schedule'         => 'once',
            'minutes_interval' => 30,
            'minutes_duration' => 120,
            'enabled'          => true,
            'index'            => 1,
          },
          {
            'start_date'       => '2013-12-15',
            'start_time'       => '16:23',
            'schedule'         => 'once',
            'minutes_interval' => 60,
            'minutes_duration' => 240,
            'enabled'          => true,
            'index'            => 2,
          }
        ])
      end

      it 'should skip triggers Win32::TaskScheduler cannot handle' do
        @mock_task.expects(:triggers).returns([{
          'start_date'       => '2011-10-13',
          'start_time'       => '14:21',
          'schedule'         => 'once',
          'minutes_interval' => 0,
          'minutes_duration' => 0,
          'enabled'          => true,
          'index'            => 0,
        },
        nil,
        {
          'start_date'       => '2013-12-15',
          'start_time'       => '16:23',
          'schedule'         => 'once',
          'minutes_interval' => 0,
          'minutes_duration' => 0,
          'enabled'          => true,
          'index'            => 2,
        }])

        expect(resource.provider.trigger).to match_array([
          {
            'start_date'       => '2011-10-13',
            'start_time'       => '14:21',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          },
          {
            'start_date'       => '2013-12-15',
            'start_time'       => '16:23',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 2,
          }
        ])
      end

      it 'should skip trigger types Puppet does not handle' do
        @mock_task.expects(:triggers).returns([{
          'start_date'       => '2011-10-13',
          'start_time'       => '14:21',
          'schedule'         => 'once',
          'minutes_interval' => 0,
          'minutes_duration' => 0,
          'enabled'          => true,
          'index'            => 0,
        },
        nil,
        {
          'start_date'       => '2013-12-15',
          'start_time'       => '16:23',
          'schedule'         => 'once',
          'minutes_interval' => 0,
          'minutes_duration' => 0,
          'enabled'          => true,
          'index'            => 2,
        }])

        expect(resource.provider.trigger).to match_array([
          {
            'start_date'       => '2011-10-13',
            'start_time'       => '14:21',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 0,
          },
          {
            'start_date'       => '2013-12-15',
            'start_time'       => '16:23',
            'schedule'         => 'once',
            'minutes_interval' => 0,
            'minutes_duration' => 0,
            'enabled'          => true,
            'index'            => 2,
          }
        ])
      end
    end

    it 'should get the working directory from the working_directory on the task' do
      @mock_task.expects(:working_directory).returns('C:\Windows\System32')

      expect(resource.provider.working_dir).to eq('C:\Windows\System32')
    end

    it 'should get the command from the application_name on the task' do
      @mock_task.expects(:application_name).returns('C:\Windows\System32\notepad.exe')

      expect(resource.provider.command).to eq('C:\Windows\System32\notepad.exe')
    end

    it 'should get the command arguments from the parameters on the task' do
      @mock_task.expects(:parameters).returns('these are my arguments')

      expect(resource.provider.arguments).to eq('these are my arguments')
    end

    it 'should get the compatibility from the parameters on the task' do
      skip("provider #{resource.provider} doesn't support compatibility") unless resource.provider.respond_to?(:compatibility)
      @mock_task.expects(:compatibility).returns(3)

      expect(resource.provider.compatibility).to eq(3)
    end

    it 'should get the user from the account_information on the task' do
      @mock_task.expects(:account_information).returns('this is my user')

      expect(resource.provider.user).to eq('this is my user')
    end

    describe 'whether the task is enabled' do
      it 'should report tasks with the disabled bit set as disabled' do
        @mock_task.stubs(:enabled).returns(false)

        expect(resource.provider.enabled).to eq(:false)
      end

      it 'should report tasks without the disabled bit set as enabled' do
        @mock_task.stubs(:enabled).returns(true)

        expect(resource.provider.enabled).to eq(:true)
      end

      it 'should not consider triggers for determining if the task is enabled' do
        @mock_task.stubs(:enabled).returns(:true)
        @mock_task.stubs(:trigger_count).returns(1)
        manifest = PuppetX::PuppetLabs::ScheduledTask::Trigger::Manifest
        default_once = manifest.default_trigger_for('once').merge(
          { 'enabled' => false, }
        )

        @mock_task.stubs(:trigger).with(0).returns(default_once)
        expect(resource.provider.enabled).to eq(:true)
      end
    end
  end

  describe '#exists?' do
    before :each do
      @mock_task = stub
      @mock_task.responds_like_instance_of(task2)
      described_class.any_instance.stubs(:task).returns(@mock_task)

      task2.stubs(:new).returns(@mock_task)
    end
    let(:resource) { Puppet::Type.type(:scheduled_task).new(:name => 'Test Task', :command => 'C:\Windows\System32\notepad.exe') }

    it "should delegate to #{task2.name.to_s} using the resource's name" do
      task2.expects(:exists?).with('Test Task').returns(true)

      expect(resource.provider.exists?).to eq(true)
    end
  end

  describe '.instances' do
    it 'should use the list of task names to construct the list of scheduled_tasks' do
      job_files = ['foo', 'bar', 'baz']
      task2.stubs(:tasks).returns(job_files)
      job_files.each do |job|
        described_class.expects(:new).with(:provider => task_provider, :name => job)
      end

      described_class.instances
    end
  end

  describe '#user_insync?', :if => Puppet.features.microsoft_windows? do
    let(:resource) { described_class.new(:name => 'foobar', :command => 'C:\Windows\System32\notepad.exe') }

    it 'should consider the user as in sync if the name matches' do
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('joe').twice.returns('SID A')

      expect(resource).to be_user_insync('joe', ['joe'])
    end

    it 'should consider the user as in sync if the current user is fully qualified' do
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('joe').returns('SID A')
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('MACHINE\joe').returns('SID A')

      expect(resource).to be_user_insync('MACHINE\joe', ['joe'])
    end

    it 'should consider a current user of the empty string to be the same as the system user' do
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('system').twice.returns('SYSTEM SID')

      expect(resource).to be_user_insync('', ['system'])
    end

    it 'should consider different users as being different' do
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('joe').returns('SID A')
      Puppet::Util::Windows::SID.expects(:name_to_sid).with('bob').returns('SID B')

      expect(resource).not_to be_user_insync('joe', ['bob'])
    end
  end

  describe '#trigger_insync?' do
    let(:resource) { described_class.new(:name => 'foobar', :command => 'C:\Windows\System32\notepad.exe') }

    it 'should not consider any extra current triggers as in sync' do
      current = [
        {'start_date' => '2011-9-12', 'start_time' => '15:15', 'schedule' => 'once'},
        {'start_date' => '2012-10-13', 'start_time' => '16:16', 'schedule' => 'once'}
      ]
      desired = {'start_date' => '2011-09-12', 'start_time' => '15:15', 'schedule' => 'once'}

      expect(resource).not_to be_trigger_insync(current, desired)
    end

    it 'should not consider any extra desired triggers as in sync' do
      current = {'start_date' => '2011-9-12', 'start_time' => '15:15', 'schedule' => 'once'}
      desired = [
        {'start_date' => '2011-09-12', 'start_time' => '15:15', 'schedule' => 'once'},
        {'start_date' => '2012-10-13', 'start_time' => '16:16', 'schedule' => 'once'}
      ]

      expect(resource).not_to be_trigger_insync(current, desired)
    end

    it 'should consider triggers to be in sync if the sets of current and desired triggers are equal' do
      current = [
        {'start_date' => '2011-9-12', 'start_time' => '15:15', 'schedule' => 'once'},
        {'start_date' => '2012-10-13', 'start_time' => '16:16', 'schedule' => 'once'}
      ]
      desired = [
        {'start_date' => '2011-09-12', 'start_time' => '15:15', 'schedule' => 'once'},
        {'start_date' => '2012-10-13', 'start_time' => '16:16', 'schedule' => 'once'}
      ]

      expect(resource).to be_trigger_insync(current, desired)
    end
  end

  describe '#triggers_same?' do
    let(:provider) { described_class.new(:name => 'foobar', :command => 'C:\Windows\System32\notepad.exe') }

    it "should not mutate triggers" do
      current = {'schedule' => 'daily', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3}
      current.freeze

      desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30'}
      desired.freeze

      expect(provider).to be_triggers_same(current, desired)
    end

    it "ignores 'index' in current trigger" do
      current = {'index' => 0, 'schedule' => 'daily', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3}
      desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}

      expect(provider).to be_triggers_same(current, desired)
    end

    it "ignores 'enabled' in current triggger" do
      current = {'enabled' => true, 'schedule' => 'daily', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3}
      desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}

      expect(provider).to be_triggers_same(current, desired)
    end

    it "should not consider a disabled 'current' trigger to be the same" do
      current = {'schedule' => 'once', 'enabled' => false}
      desired = {'schedule' => 'once'}

      expect(provider).not_to be_triggers_same(current, desired)
    end

    it 'should not consider triggers with different schedules to be the same' do
      current = {'schedule' => 'daily', 'start_date' => '2011-9-12', 'start_time' => '15:30'}
      desired = {'schedule' => 'once',  'start_date' => '2011-09-12', 'start_time' => '15:30'}

      expect(provider).not_to be_triggers_same(current, desired)
    end

    it 'should not consider triggers with different monthly types to be the same' do
      # A trigger of type :TASK_TIME_TRIGGER_MONTHLYDATE
      current = {'schedule' => 'monthly', 'start_time' => '14:00', 'months' => [1,2,3,4,5,6,7,8,9,10,11,12], 'on' => [9]}
      # A trigger of type :TASK_TIME_TRIGGER_MONTHLYDOW
      desired = {'schedule' => 'monthly', 'start_time' => '14:00', 'which_occurrence' => 'second', 'day_of_week' => ['sat']}

      expect(provider).not_to be_triggers_same(current, desired)
    end

    describe 'start_date' do
      it "considers triggers to be equal when start_date is not specified in the 'desired' trigger" do
        current = {'schedule' => 'daily', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'daily', 'start_time' => '15:30', 'every' => 3}

        expect(provider).to be_triggers_same(current, desired)
      end
    end

    describe 'comparing daily triggers' do
      it "should consider 'desired' triggers not specifying 'every' to have the same value as the 'current' trigger" do
        current = {'schedule' => 'daily', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30'}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'start_dates' as different triggers" do
        current = {'schedule' => 'daily', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'daily', 'start_date' => '2012-09-12', 'start_time' => '15:30', 'every' => 3}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'start_times' as different triggers" do
        current = {'schedule' => 'daily', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:31', 'every' => 3}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should not consider differences in date formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-9-12',  'start_time' => '15:30', 'every' => 3}

        expect(provider).to be_triggers_same(current, desired)
      end

      it 'should not consider differences in time formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '05:30',  'every' => 3}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '5:30', 'every' => 3}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'every' as different triggers" do
        current = {'schedule' => 'daily', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3}
        desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 1}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should consider triggers that are the same as being the same' do
        trigger = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '01:30', 'every' => 1}

        expect(provider).to be_triggers_same(trigger, trigger)
      end
    end

    describe 'comparing one-time triggers' do
      it "should consider different 'start_dates' as different triggers" do
        current = {'schedule' => 'daily', 'start_date' => '2011-9-12', 'start_time' => '15:30'}
        desired = {'schedule' => 'daily', 'start_date' => '2012-09-12', 'start_time' => '15:30'}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'start_times' as different triggers" do
        current = {'schedule' => 'daily', 'start_date' => '2011-9-12', 'start_time' => '15:30'}
        desired = {'schedule' => 'daily', 'start_date' => '2011-09-12', 'start_time' => '15:31'}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should not consider differences in date formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '15:30'}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12',  'start_time' => '15:30'}

        expect(provider).to be_triggers_same(current, desired)
      end

      it 'should not consider differences in time formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '01:30'}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '1:30'}

        expect(provider).to be_triggers_same(current, desired)
      end

      it 'should consider triggers that are the same as being the same' do
        trigger = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '01:30'}

        expect(provider).to be_triggers_same(trigger, trigger)
      end
    end

    describe 'comparing monthly date-based triggers' do
      it "should consider 'desired' triggers not specifying 'months' to have the same value as the 'current' trigger" do
        current = {'schedule' => 'monthly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'months' => [3], 'on' => [1,'last']}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'on' => [1, 'last']}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'start_dates' as different triggers" do
        current = {'schedule' => 'monthly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-10-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'start_times' as different triggers" do
        current = {'schedule' => 'monthly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '22:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should not consider differences in date formatting to be different triggers' do
        current = {'schedule' => 'monthly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-09-12',  'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}

        expect(provider).to be_triggers_same(current, desired)
      end

      it 'should not consider differences in time formatting to be different triggers' do
        current = {'schedule' => 'monthly', 'start_date' => '2011-9-12', 'start_time' => '05:30',  'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '5:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'months' as different triggers" do
        current = {'schedule' => 'monthly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'months' => [1],    'on' => [1, 3, 5, 7]}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'on' as different triggers" do
        current = {'schedule' => 'monthly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}
        desired = {'schedule' => 'monthly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 5, 7]}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should consider triggers that are the same as being the same' do
        trigger = {'schedule' => 'monthly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'months' => [1, 2], 'on' => [1, 3, 5, 7]}

        expect(provider).to be_triggers_same(trigger, trigger)
      end
    end

    describe 'comparing monthly day-of-week-based triggers' do
      it "should consider 'desired' triggers not specifying 'months' to have the same value as the 'current' trigger" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-9-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'start_dates' as different triggers" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-9-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-10-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'start_times' as different triggers" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-9-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '22:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'months' as different triggers" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-9-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3, 5, 7, 9],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'which_occurrence' as different triggers" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-9-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'last',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'day_of_week' as different triggers" do
        current = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-9-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }
        desired = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-09-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['fri']
        }

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should consider triggers that are the same as being the same' do
        trigger = {
          'schedule'         => 'monthly',
          'start_date'       => '2011-9-12',
          'start_time'       => '15:30',
          'months'           => [3],
          'which_occurrence' => 'first',
          'day_of_week'      => ['mon', 'tues', 'sat']
        }

        expect(provider).to be_triggers_same(trigger, trigger)
      end
    end

    describe 'comparing weekly triggers' do
      it "should consider 'desired' triggers not specifying 'day_of_week' to have the same value as the 'current' trigger" do
        current = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'start_dates' as different triggers" do
        current = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-10-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'start_times' as different triggers" do
        current = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '22:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should not consider differences in date formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-9-12',  'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).to be_triggers_same(current, desired)
      end

      it 'should not consider differences in time formatting to be different triggers' do
        current = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '01:30',  'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '1:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).to be_triggers_same(current, desired)
      end

      it "should consider different 'every' as different triggers" do
        current = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 1, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it "should consider different 'day_of_week' as different triggers" do
        current = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}
        desired = {'schedule' => 'weekly', 'start_date' => '2011-09-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['fri']}

        expect(provider).not_to be_triggers_same(current, desired)
      end

      it 'should consider triggers that are the same as being the same' do
        trigger = {'schedule' => 'weekly', 'start_date' => '2011-9-12', 'start_time' => '15:30', 'every' => 3, 'day_of_week' => ['mon', 'wed', 'fri']}

        expect(provider).to be_triggers_same(trigger, trigger)
      end
    end
  end

  describe '#validate_trigger' do
    let(:provider) { described_class.new(:name => 'Test Task', :command => 'C:\Windows\System32\notepad.exe') }

    it 'should succeed if all passed triggers translate from hashes to triggers' do
      triggers_to_validate = [
        {'schedule' => 'once',   'start_date' => '2011-09-13', 'start_time' => '13:50'},
        {'schedule' => 'weekly', 'start_date' => '2011-09-13', 'start_time' => '13:50', 'day_of_week' => 'mon'}
      ]

      expect(provider.validate_trigger(triggers_to_validate)).to eq(true)
    end

    it 'should use the exception from from_manifest_hash when it fails' do
      triggers_to_validate = [
        {'schedule' => 'once', 'start_date' => '2011-09-13', 'start_time' => '13:50'},
        {'schedule' => 'monthly', 'this is invalid' => true}
      ]

      expect {provider.validate_trigger(triggers_to_validate)}.to raise_error(
        /#{Regexp.escape("Unknown trigger option(s): ['this is invalid']")}/
      )
    end

    it 'should raise when an invalid day_of_week is passed' do
      triggers_to_validate = [
        {'schedule' => 'weekly', 'start_date' => '2011-09-13', 'start_time' => '13:50', 'day_of_week' => 'BadDay'}
      ]

      expect {provider.validate_trigger(triggers_to_validate)}.to raise_error(
        /#{Regexp.escape("Unknown day_of_week values(s): [\"BadDay\"]")}/
      )
    end
  end

  describe '#flush' do
    let(:resource) do
      Puppet::Type.type(:scheduled_task).new(
        :name    => 'Test Task',
        :command => 'C:\Windows\System32\notepad.exe',
        :ensure  => @ensure
      )
    end

    before :each do
      @mock_task = stub
      @mock_task.responds_like_instance_of(task2)
      task2.stubs(:new).returns(@mock_task)

      @command = 'C:\Windows\System32\notepad.exe'
    end

    describe 'when :ensure is :present' do
      before :each do
        @ensure = :present
      end

      it 'should save the task' do
        # prevents a lookup / task enumeration on non-Windows systems
        task2.stubs(:exists?).returns(true)

        @mock_task.expects(:set_account_information).with(nil, nil)
        @mock_task.expects(:save)

        resource.provider.flush
      end

      it 'should fail if the command is not specified' do
        resource = Puppet::Type.type(:scheduled_task).new(
          :name    => 'Test Task',
          :ensure  => @ensure
        )

        expect { resource.provider.flush }.to raise_error(
          Puppet::Error,
          'Parameter command is required.'
        )
      end
    end

    describe 'when :ensure is :absent' do
      before :each do
        @ensure = :absent
        task2.stubs(:new).returns(@mock_task)
      end

      it 'should not save the task if :ensure is :absent' do
        @mock_task.expects(:save).never

        resource.provider.flush
      end

      it 'should not fail if the command is not specified' do
        @mock_task.stubs(:save)

        resource = Puppet::Type.type(:scheduled_task).new(
          :name    => 'Test Task',
          :ensure  => @ensure
        )

        resource.provider.flush
      end
    end
  end

  describe 'property setter methods' do
    let(:resource) do
      Puppet::Type.type(:scheduled_task).new(
        :name    => 'Test Task',
        :command => 'C:\dummy_task.exe'
      )
    end

    before :each do
        @mock_task = stub
        @mock_task.responds_like_instance_of(task2)
        # prevents a lookup / task enumeration on non-Windows systems
        task2.stubs(:exists?).returns(true)
        task2.stubs(:new).returns(@mock_task)
    end

    describe '#command=' do
      it 'should set the application_name on the task' do
        @mock_task.expects(:application_name=).with('C:\Windows\System32\notepad.exe')

        resource.provider.command = 'C:\Windows\System32\notepad.exe'
      end
    end

    describe '#arguments=' do
      it 'should set the parameters on the task' do
        @mock_task.expects(:parameters=).with(['/some /arguments /here'])

        resource.provider.arguments = ['/some /arguments /here']
      end
    end

    describe '#working_dir=' do
      it 'should set the working_directory on the task' do
        @mock_task.expects(:working_directory=).with('C:\Windows\System32')

        resource.provider.working_dir = 'C:\Windows\System32'
      end
    end

    describe '#enabled=' do
      it 'should set the enabled property if the task should be disabled' do
        @mock_task.stubs(:enabled).returns(true)
        @mock_task.expects(:enabled=).with(false)

        resource.provider.enabled = :false
      end

      it 'should clear the enabled property if the task should be enabled' do
        @mock_task.stubs(:enabled).returns(false)
        @mock_task.expects(:enabled=).with(true)

        resource.provider.enabled = :true
      end
    end

    describe '#trigger=' do
      let(:resource) do
        Puppet::Type.type(:scheduled_task).new(
          :name    => 'Test Task',
          :command => 'C:\Windows\System32\notepad.exe',
          :trigger => @trigger
        )
      end

      before :each do
        @mock_task = stub
        @mock_task.responds_like_instance_of(task2)
        task2.stubs(:new).returns(@mock_task)
      end

      it 'should not consider all duplicate current triggers in sync with a single desired trigger' do
        @trigger = {'schedule' => 'once', 'start_date' => '2011-09-15', 'start_time' => '15:10'}
        current_triggers = [
          {'schedule' => 'once', 'start_date' => '2011-9-15', 'start_time' => '15:10', 'index' => 0},
          {'schedule' => 'once', 'start_date' => '2011-9-15', 'start_time' => '15:10', 'index' => 1},
          {'schedule' => 'once', 'start_date' => '2011-9-15', 'start_time' => '15:10', 'index' => 2},
        ]
        resource.provider.stubs(:trigger).returns(current_triggers)
        @mock_task.expects(:delete_trigger).with(1)
        @mock_task.expects(:delete_trigger).with(2)

        resource.provider.trigger = @trigger
      end

      it 'should remove triggers not defined in the resource' do
        @trigger = {'schedule' => 'once', 'start_date' => '2011-09-15', 'start_time' => '15:10'}
        current_triggers = [
          {'schedule' => 'once', 'start_date' => '2011-9-15', 'start_time' => '15:10', 'index' => 0},
          {'schedule' => 'once', 'start_date' => '2012-9-15', 'start_time' => '15:10', 'index' => 1},
          {'schedule' => 'once', 'start_date' => '2013-9-15', 'start_time' => '15:10', 'index' => 2},
        ]
        resource.provider.stubs(:trigger).returns(current_triggers)
        @mock_task.expects(:delete_trigger).with(1)
        @mock_task.expects(:delete_trigger).with(2)

        resource.provider.trigger = @trigger
      end

      it 'should add triggers defined in the resource, but not found on the system' do
        @trigger = [
          {'schedule' => 'once', 'start_date' => '2011-09-15', 'start_time' => '15:10'},
          {'schedule' => 'once', 'start_date' => '2012-09-15', 'start_time' => '15:10'},
          {'schedule' => 'once', 'start_date' => '2013-09-15', 'start_time' => '15:10'},
        ]
        current_triggers = [
          {'schedule' => 'once', 'start_date' => '2011-9-15', 'start_time' => '15:10', 'index' => 0},
        ]
        resource.provider.stubs(:trigger).returns(current_triggers)
        @mock_task.expects(:append_trigger).with(@trigger[1])
        @mock_task.expects(:append_trigger).with(@trigger[2])

        resource.provider.trigger = @trigger
      end
    end

    describe '#user=', :if => Puppet.features.microsoft_windows? do
      before :each do
        @mock_task = stub
        @mock_task.responds_like_instance_of(task2)
        task2.stubs(:new).returns(@mock_task)
      end

      it 'should use nil for user and password when setting the user to the SYSTEM account' do
        Puppet::Util::Windows::SID.stubs(:name_to_sid).with('system').returns('SYSTEM SID')

        resource = Puppet::Type.type(:scheduled_task).new(
          :name    => 'Test Task',
          :command => 'C:\dummy_task.exe',
          :user    => 'system'
        )

        @mock_task.expects(:set_account_information).with(nil, nil)

        resource.provider.user = 'system'
      end

      it 'should use the specified user and password when setting the user to anything other than SYSTEM' do
        Puppet::Util::Windows::SID.stubs(:name_to_sid).with('my_user_name').returns('SID A')

        resource = Puppet::Type.type(:scheduled_task).new(
          :name     => 'Test Task',
          :command  => 'C:\dummy_task.exe',
          :user     => 'my_user_name',
          :password => 'my password'
        )

        @mock_task.expects(:set_account_information).with('my_user_name', 'my password')

        resource.provider.user = 'my_user_name'
      end
    end

    describe '#compatibility=' do
      it 'should set the parameters on the task' do
        skip("provider #{resource.provider} doesn't support compatibility") unless resource.provider.respond_to?(:compatibility)
        @mock_task.expects(:compatibility=).with(1)

        resource.provider.compatibility = 1
      end
    end
  end

  describe '#create' do
    let(:resource) do
      Puppet::Type.type(:scheduled_task).new(
        :name          => 'Test Task',
        :enabled       => @enabled,
        :command       => @command,
        :arguments     => @arguments,
        :compatibility => @compatibility,
        :working_dir   => @working_dir,
        :trigger       => { 'schedule' => 'once', 'start_date' => '2011-09-27', 'start_time' => '17:00' }
      )
    end

    before :each do
      @enabled       = :true
      @command       = 'C:\Windows\System32\notepad.exe'
      @arguments     = '/a /list /of /arguments'
      @compatibility = 1
      @working_dir   = 'C:\Windows\Some\Directory'

      @mock_task = stub
      @mock_task.responds_like_instance_of(task2)
      @mock_task.stubs(:application_name=)
      @mock_task.stubs(:parameters=)
      @mock_task.stubs(:working_directory=)
      @mock_task.stubs(:set_account_information)
      @mock_task.stubs(:enabled)
      @mock_task.stubs(:enabled=)
      @mock_task.stubs(:triggers).returns([])
      @mock_task.stubs(:append_trigger)
      if resource.provider.is_a?(Puppet::Type::Scheduled_task::ProviderTaskscheduler_api2)
        # allow compatibility to set given newer provider allows it
        @mock_task.stubs(:compatibility=)
      end
      @mock_task.stubs(:save)
      task2.stubs(:new).returns(@mock_task)

      described_class.any_instance.stubs(:sync_triggers)
    end

    it 'should set the command' do
      resource.provider.expects(:command=).with(@command)

      resource.provider.create
    end

    it 'should set the arguments' do
      resource.provider.expects(:arguments=).with(@arguments)

      resource.provider.create
    end

    it 'should set the compatibility' do
      skip("provider #{resource.provider} doesn't support compatibility") unless resource.provider.respond_to?(:compatibility)
      resource.provider.expects(:compatibility=).with(@compatibility)

      resource.provider.create
    end

    it 'should set the working_dir' do
      resource.provider.expects(:working_dir=).with(@working_dir)

      resource.provider.create
    end

    it "should set the user" do
      resource.provider.expects(:user=).with(:system)

      resource.provider.create
    end

    it 'should set the enabled property' do
      resource.provider.expects(:enabled=)

      resource.provider.create
    end

    it 'should sync triggers' do
      resource.provider.expects(:trigger=)

      resource.provider.create
    end

    describe 'should reset any internal state prior' do
      before :each do
        @new_mock_task = stub
        @new_mock_task.responds_like_instance_of(task2)
        @new_mock_task.stubs(:application_name=)
        @new_mock_task.stubs(:parameters=)
        @new_mock_task.stubs(:working_directory=)
        @new_mock_task.stubs(:enabled)
        @new_mock_task.stubs(:enabled=)
        @new_mock_task.stubs(:delete_trigger)
        @new_mock_task.stubs(:append_trigger)
        @new_mock_task.stubs(:set_account_information)
        @new_mock_task.stubs(:compatibility=)
        task2.stubs(:new).returns(@mock_task, @new_mock_task)

        # prevents a lookup / task enumeration on non-Windows systems
        task2.stubs(:exists?).returns(false)
      end

      it 'by clearing the cached task object' do
        @new_mock_task.stubs(:triggers).returns([])

        expect(resource.provider.task).to eq(@mock_task)
        expect(resource.provider.task).to eq(@mock_task)

        resource.provider.create

        expect(resource.provider.task).to eq(@new_mock_task)
      end

      it 'by clearing the cached list of triggers for the task' do
        manifest = PuppetX::PuppetLabs::ScheduledTask::Trigger::Manifest
        default_once = manifest.default_trigger_for('once').merge({'index' => 0})
        @mock_task.stubs(:triggers).returns([default_once])

        default_daily = manifest.default_trigger_for('daily').merge({'index' => 0})
        @new_mock_task.stubs(:triggers).returns([default_daily])

        converted_once = default_once.merge({'index' => 0})
        expect(resource.provider.trigger).to eq([converted_once])
        expect(resource.provider.trigger).to eq([converted_once])

        resource.provider.create

        converted_daily = default_daily.merge({'index' => 0})
        expect(resource.provider.trigger).to eq([converted_daily])
      end
    end
  end

  describe "Win32::TaskScheduler", :if => Puppet.features.microsoft_windows? do

    let(:name) { SecureRandom.uuid }

    describe 'sets appropriate generic trigger defaults' do
      before(:each) do
        @now = Time.now
        Time.stubs(:now).returns(@now)
      end

      it 'for a ONCE schedule' do
        task = Win32::TaskScheduler.new(name, { 'trigger_type' => :TASK_TIME_TRIGGER_ONCE })
        expect(task.trigger(0)['start_year']).to eq(@now.year)
        expect(task.trigger(0)['start_month']).to eq(@now.month)
        expect(task.trigger(0)['start_day']).to eq(@now.day)
      end

      it 'for a DAILY schedule' do
        trigger = {
          'trigger_type' => :TASK_TIME_TRIGGER_DAILY,
          'type' => { 'days_interval' => 1 }
        }
        task = Win32::TaskScheduler.new(name, trigger)

        expect(task.trigger(0)['start_year']).to eq(@now.year)
        expect(task.trigger(0)['start_month']).to eq(@now.month)
        expect(task.trigger(0)['start_day']).to eq(@now.day)
      end

      it 'for a WEEKLY schedule' do
        trigger = {
          'trigger_type' => :TASK_TIME_TRIGGER_WEEKLY,
          'type' => { 'weeks_interval' => 1, 'days_of_week' => 1 }
        }
        task = Win32::TaskScheduler.new(name, trigger)

        expect(task.trigger(0)['start_year']).to eq(@now.year)
        expect(task.trigger(0)['start_month']).to eq(@now.month)
        expect(task.trigger(0)['start_day']).to eq(@now.day)
      end

      it 'for a MONTHLYDATE schedule' do
        trigger = {
          'trigger_type' => :TASK_TIME_TRIGGER_MONTHLYDATE,
          'type' => { 'days' => 1, 'months' => 1 }
        }
        task = Win32::TaskScheduler.new(name, trigger)

        expect(task.trigger(0)['start_year']).to eq(@now.year)
        expect(task.trigger(0)['start_month']).to eq(@now.month)
        expect(task.trigger(0)['start_day']).to eq(@now.day)
      end

      it 'for a MONTHLYDOW schedule' do
        trigger = {
          'trigger_type' => :TASK_TIME_TRIGGER_MONTHLYDOW,
          'type' => { 'weeks' => 1, 'days_of_week' => 1, 'months' => 1 }
        }
        task = Win32::TaskScheduler.new(name, trigger)

        expect(task.trigger(0)['start_year']).to eq(@now.year)
        expect(task.trigger(0)['start_month']).to eq(@now.month)
        expect(task.trigger(0)['start_day']).to eq(@now.day)
      end
    end

    describe 'enforces maximum lengths' do
      let(:task) { Win32::TaskScheduler.new(name, { 'trigger_type' => :TASK_TIME_TRIGGER_ONCE }) }

      it 'on account user name' do
        expect {
          task.set_account_information('a' * (Win32::TaskScheduler::MAX_ACCOUNT_LENGTH + 1), 'pass')
        }.to raise_error(Puppet::Error)
      end

      it 'on application name' do
        expect {
          task.application_name = 'a' * (Win32::TaskScheduler::MAX_PATH + 1)
        }.to raise_error(Puppet::Error)
      end

      it 'on parameters' do
        expect {
          task.parameters = 'a' * (Win32::TaskScheduler::MAX_PARAMETERS_LENGTH + 1)
        }.to raise_error(Puppet::Error)
      end

      it 'on working directory' do
        expect {
          task.working_directory = 'a' * (Win32::TaskScheduler::MAX_PATH + 1)
        }.to raise_error(Puppet::Error)
      end

      it 'on comment' do
        expect {
          task.comment = 'a' * (Win32::TaskScheduler::MAX_COMMENT_LENGTH + 1)
        }.to raise_error(Puppet::Error)
      end

      it 'on creator' do
        expect {
          task.creator = 'a' * (Win32::TaskScheduler::MAX_ACCOUNT_LENGTH + 1)
        }.to raise_error(Puppet::Error)
      end
    end

    def delete_task_with_retry(task, name, attempts = 3)
      failed = false

      attempts.times do
        begin
          task.delete(name) if Win32::TaskScheduler.new.exists?(name)
        rescue Puppet::Util::Windows::Error
          failed = true
        end

        if failed then sleep 1 else break end
      end
    end

    describe '#exists?' do
      it 'works with Unicode task names' do
        task_name = name + "\u16A0\u16C7\u16BB" # ᚠᛇᚻ

        begin
          task = Win32::TaskScheduler.new(task_name, { 'trigger_type' => :TASK_TIME_TRIGGER_ONCE })
          task.save()

          expect(Puppet::FileSystem.exist?("C:\\Windows\\Tasks\\#{task_name}.job")).to be_truthy
          expect(task.exists?(task_name)).to be_truthy
        ensure
          delete_task_with_retry(task, task_name)
        end
      end

      it 'is case insensitive' do
        task_name = name + 'abc' # name is a guid, but might not have alpha chars

        begin
          task = Win32::TaskScheduler.new(task_name.upcase, { 'trigger_type' => :TASK_TIME_TRIGGER_ONCE })
          task.save()

          expect(task.exists?(task_name.downcase)).to be_truthy
        ensure
          delete_task_with_retry(task, task_name)
        end
      end
    end

    describe 'does not corrupt tasks' do
      it 'when setting maximum length values for all settings' do
        begin
          task = Win32::TaskScheduler.new(name, { 'trigger_type' => :TASK_TIME_TRIGGER_ONCE })

          application_name = 'a' * Win32::TaskScheduler::MAX_PATH
          parameters = 'b' * Win32::TaskScheduler::MAX_PARAMETERS_LENGTH
          working_directory = 'c' * Win32::TaskScheduler::MAX_PATH
          comment = 'd' * Win32::TaskScheduler::MAX_COMMENT_LENGTH
          creator = 'e' * Win32::TaskScheduler::MAX_ACCOUNT_LENGTH

          task.application_name = application_name
          task.parameters = parameters
          task.working_directory = working_directory
          task.comment = comment
          task.creator = creator

          # saving and reloading (activating) can induce COM load errors when
          # file is corrupted, which can happen when the upper bounds of these lengths are set too high
          task.save()
          task.activate(name)

          # furthermore, corrupted values may not necessarily be read back properly
          # note that SYSTEM is always returned as an empty string in account_information
          expect(task.account_information).to eq('')
          expect(task.application_name).to eq(application_name)
          expect(task.parameters).to eq(parameters)
          expect(task.working_directory).to eq(working_directory)
          expect(task.comment).to eq(comment)
          expect(task.creator).to eq(creator)
        ensure
          delete_task_with_retry(task, name)
        end
      end

      it 'by preventing a save() not preceded by a set_account_information()' do
        begin
          # creates a default new task with SYSTEM user
          task = Win32::TaskScheduler.new(name, { 'trigger_type' => :TASK_TIME_TRIGGER_ONCE })
          # save automatically resets the current task
          task.save()

          # re-activate named task, try to modify, and save
          task.activate(name)
          task.application_name = 'c:/windows/system32/notepad.exe'

          expect { task.save() }.to raise_error(Puppet::Error, /Account information must be set on the current task to save it properly/)

          # on a failed save, the current task is still active - add SYSTEM
          task.set_account_information('', nil)
          expect(task.save()).to be_instance_of(Win32::TaskScheduler::COM::Task)

          # the most appropriate additional validation here would be to confirm settings with schtasks.exe
          # but that test can live inside a system-level acceptance test
        ensure
          delete_task_with_retry(task, name)
        end
      end
    end
  end
end

end
