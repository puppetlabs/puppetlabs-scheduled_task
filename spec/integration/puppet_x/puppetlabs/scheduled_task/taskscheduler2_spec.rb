#!/usr/bin/env ruby
require 'spec_helper'
require 'puppet_x/puppetlabs/scheduled_task/taskscheduler2'
require 'puppet_x/puppetlabs/scheduled_task/trigger'
require 'puppet_x/puppetlabs/scheduled_task/v1adapter'

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

ST = PuppetX::PuppetLabs::ScheduledTask

def create_test_task(task_name = nil, task_compatiblity = ST::TaskScheduler2::TASK_COMPATIBILITY::TASK_COMPATIBILITY_V2)
  tasksched = ST::TaskScheduler2
  task_name = tasksched::ROOT_FOLDER + 'puppet_task_' + SecureRandom.uuid.to_s if task_name.nil?
  _, definition = tasksched.task(task_name)
  # Set task settings
  definition.Settings.Compatibility = task_compatiblity
  definition.Principal.UserId = 'SYSTEM'
  definition.Principal.LogonType = tasksched::TASK_LOGON_TYPE::TASK_LOGON_SERVICE_ACCOUNT
  definition.Principal.RunLevel = tasksched::TASK_RUNLEVEL_TYPE::TASK_RUNLEVEL_HIGHEST
  definition.Settings.Enabled = false
  # Create a trigger
  trigger = definition.Triggers.Create(ST::Trigger::V2::Type::TASK_TRIGGER_TIME)
  trigger.StartBoundary = '2017-09-11T14:02:00'
  # Create an action
  new_action = definition.Actions.Create(tasksched::TASK_ACTION_TYPE::TASK_ACTION_EXEC)
  new_action.Path = 'cmd.exe'
  new_action.Arguments = '/c exit 0'
  tasksched.save(task_name, definition)

  task_name
end

describe "PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2", :if => Puppet.features.microsoft_windows? do
  let(:subject) { PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2 }

end
