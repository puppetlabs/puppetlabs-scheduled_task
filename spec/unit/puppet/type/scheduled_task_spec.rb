#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:scheduled_task), :if => Puppet.features.microsoft_windows? do

  it 'should use name as the namevar' do
    expect(described_class.new(
      :title   => 'Foo',
      :command => 'C:\Windows\System32\notepad.exe'
    ).name).to eq('Foo')
  end

  it 'should use taskscheduler_api2 as the default provider' do
    expect(described_class.defaultprovider).to eq( Puppet::Type::Scheduled_task::ProviderTaskscheduler_api2)
  end

  describe 'when setting the command' do
    it 'should accept an absolute path to the command' do
      expect(described_class.new(:name => 'Test Task', :command => 'C:\Windows\System32\notepad.exe')[:command]).to eq('C:\Windows\System32\notepad.exe')
    end

    it 'should convert forward slashes to backslashes' do
      expect(described_class.new(
        :name      => 'Test Task',
        :command   => 'C:/Windows/System32/notepad.exe'
      )[:command]).to eq('C:\Windows\System32\notepad.exe')
    end

    it 'should normalize backslashes' do
      expect(described_class.new(
        :name      => 'Test Task',
        :command   => 'C:\Windows\\System32\\\\notepad.exe'
      )[:command]).to eq('C:\Windows\System32\notepad.exe')
    end

    it 'should fail if the path to the command is not absolute' do
      expect {
        described_class.new(:name => 'Test Task', :command => 'notepad.exe')
      }.to raise_error(
        Puppet::Error,
        /Parameter command failed on Scheduled_task\[Test Task\]: Must be specified using an absolute path\./
      )
    end
  end

  describe 'when setting the command arguments' do
    it 'should accept a string' do
      expect(described_class.new(
        :name      => 'Test Task',
        :command   => 'C:\Windows\System32\notepad.exe',
        :arguments => '/a /b /c'
      )[:arguments]).to eq('/a /b /c')
    end

    it 'should allow not specifying any command arguments' do
      expect(described_class.new(
        :name    => 'Test Task',
        :command => 'C:\Windows\System32\notepad.exe'
      )[:arguments]).not_to be
    end
  end

  describe 'when setting whether the task is enabled or not' do
    it 'should return true when enabled is set to true' do
      expect(described_class.new(
        :title   => 'Foo',
        :command => 'C:\Windows\System32\notepad.exe',
        :enabled => 'true',
      )[:enabled]).to eq(:true)
    end

    it 'should return false when enabled is set to false' do
      expect(described_class.new(
        :title   => 'Foo',
        :command => 'C:\Windows\System32\notepad.exe',
        :enabled => 'false',
      )[:enabled]).to eq(:false)
    end
  end

  describe 'when setting the working directory' do
    it 'should accept an absolute path to the working directory' do
      expect(described_class.new(
        :name        => 'Test Task',
        :command     => 'C:\Windows\System32\notepad.exe',
        :working_dir => 'C:\Windows\System32'
      )[:working_dir]).to eq('C:\Windows\System32')
    end

    it 'should fail if the path to the working directory is not absolute' do
      expect {
        described_class.new(
          :name        => 'Test Task',
          :command     => 'C:\Windows\System32\notepad.exe',
          :working_dir => 'Windows\System32'
        )
      }.to raise_error(
        Puppet::Error,
        /Parameter working_dir failed on Scheduled_task\[Test Task\]: Must be specified using an absolute path/
      )
    end

    it 'should allow not specifying any working directory' do
      expect(described_class.new(
        :name    => 'Test Task',
        :command => 'C:\Windows\System32\notepad.exe'
      )[:working_dir]).not_to be
    end
  end

  describe 'when setting the compatibility' do
    it 'should allow 1' do
      expect(described_class.new(
        :title        => 'Foo',
        :command      => 'C:\Windows\System32\notepad.exe',
        :compatibility => 1,
      )[:compatibility]).to eq(:'1')
    end

    it 'should not allow 2' do
      expect {
        described_class.new(
          :name         => 'Foo',
          :command      => 'C:\Windows\System32\notepad.exe',
          :compatibility => 2
        )
      }.to raise_error(
        Puppet::ResourceError,
        /Parameter compatibility failed on Scheduled_task\[Foo\]: Invalid value 2\. Valid values are 1\./
      )
    end
  end

  describe 'when setting the trigger' do
    it 'should delegate to the provider to validate the trigger' do
      described_class.defaultprovider.any_instance.expects(:validate_trigger).returns(true)

      described_class.new(
        :name    => 'Test Task',
        :command => 'C:\Windows\System32\notepad.exe',
        :trigger => {'schedule' => 'once', 'start_date' => '2011-09-16', 'start_time' => '13:20'}
      )
    end
  end
end
