#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:scheduled_task) do
  before :each do
    skip('Not on Windows platform') unless Puppet.features.microsoft_windows?
  end

  it 'uses name as the namevar' do
    expect(described_class.new(
      title: 'Foo',
      command: 'C:\Windows\System32\notepad.exe',
    ).name).to eq('Foo')
  end

  it 'uses taskscheduler_api2 as the default provider' do
    expect(described_class.defaultprovider).to eq(Puppet::Type::Scheduled_task::ProviderTaskscheduler_api2)
  end

  describe 'when setting the command' do
    it 'accepts an absolute path to the command' do
      expect(described_class.new(name: 'Test Task', command: 'C:\Windows\System32\notepad.exe')[:command]).to eq('C:\Windows\System32\notepad.exe')
    end

    it 'converts forward slashes to backslashes' do
      expect(described_class.new(
        name: 'Test Task',
        command: 'C:/Windows/System32/notepad.exe',
      )[:command]).to eq('C:\Windows\System32\notepad.exe')
    end

    it 'normalizes backslashes' do
      expect(described_class.new(
        name: 'Test Task',
        command: 'C:\Windows\\System32\\\\notepad.exe',
      )[:command]).to eq('C:\Windows\System32\notepad.exe')
    end

    it 'fails if the path to the command is not absolute' do
      expect {
        described_class.new(name: 'Test Task', command: 'notepad.exe')
      }.to raise_error(
        Puppet::Error,
        %r{Parameter command failed on Scheduled_task\[Test Task\]: Must be specified using an absolute path\.},
      )
    end
  end

  describe 'when setting the command arguments' do
    it 'accepts a string' do
      expect(described_class.new(
        name: 'Test Task',
        command: 'C:\Windows\System32\notepad.exe',
        arguments: '/a /b /c',
      )[:arguments]).to eq('/a /b /c')
    end

    it 'allows not specifying any command arguments' do
      expect(described_class.new(
        name: 'Test Task',
        command: 'C:\Windows\System32\notepad.exe',
      )[:arguments]).not_to be
    end
  end

  describe 'when setting whether the task is enabled or not' do
    it 'returns true when enabled is set to true' do
      expect(described_class.new(
        title: 'Foo',
        command: 'C:\Windows\System32\notepad.exe',
        enabled: 'true',
      )[:enabled]).to eq(:true)
    end

    it 'returns false when enabled is set to false' do
      expect(described_class.new(
        title: 'Foo',
        command: 'C:\Windows\System32\notepad.exe',
        enabled: 'false',
      )[:enabled]).to eq(:false)
    end
  end

  describe 'when setting the working directory' do
    it 'accepts an absolute path to the working directory' do
      expect(described_class.new(
        name: 'Test Task',
        command: 'C:\Windows\System32\notepad.exe',
        working_dir: 'C:\Windows\System32',
      )[:working_dir]).to eq('C:\Windows\System32')
    end

    it 'fails if the path to the working directory is not absolute' do
      expect {
        described_class.new(
          name: 'Test Task',
          command: 'C:\Windows\System32\notepad.exe',
          working_dir: 'Windows\System32',
        )
      }.to raise_error(
        Puppet::Error,
        %r{Parameter working_dir failed on Scheduled_task\[Test Task\]: Must be specified using an absolute path},
      )
    end

    it 'allows not specifying any working directory' do
      expect(described_class.new(
        name: 'Test Task',
        command: 'C:\Windows\System32\notepad.exe',
      )[:working_dir]).not_to be
    end
  end

  describe 'when setting the compatibility' do
    [1, 2, 3, 4, 6].each do |compat|
      it "should allow #{compat}" do
        expect(described_class.new(
          title: 'Foo',
          command: 'C:\Windows\System32\notepad.exe',
          compatibility: compat,
        )[:compatibility]).to eq(compat)
      end
    end

    it 'does not allow the string value "1"' do
      expect {
        described_class.new(
          name: 'Foo',
          command: 'C:\Windows\System32\notepad.exe',
          compatibility: '1',
        )
      }.to raise_error(
        Puppet::ResourceError,
        %r{Parameter compatibility failed on Scheduled_task\[Foo\]: must be a number},
      )
    end
  end

  describe 'when setting the trigger' do
    it 'delegates to the provider to validate the trigger' do
      let(:my_instance) { instance_double(described_class.defaultprovider) }
      allow(described_class.defaultprovider).to receive(:new).and_return(my_instance)
      allow(described_class.defaultprovider).to receive(:validate_trigger).and_return(true)

      described_class.new(
        name: 'Test Task',
        command: 'C:\Windows\System32\notepad.exe',
        trigger: { 'schedule' => 'once', 'start_date' => '2011-09-16', 'start_time' => '13:20' },
      )
    end
  end
end
