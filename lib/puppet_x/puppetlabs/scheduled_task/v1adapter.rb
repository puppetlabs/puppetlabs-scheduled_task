# This class is used to manage V1 compatible tasks using the Task Scheduler V2 API
# It is designed to be a binary compatible API to puppet/util/windows/taskscheduler.rb but
# will only surface the features used by the Puppet scheduledtask provider
#
require_relative './taskscheduler2'
require_relative './trigger'

module PuppetX
module PuppetLabs
module ScheduledTask

class V1Adapter
  public
  # Returns a new TaskScheduler object.
  # An existing task named task_name will be returned if one exists,
  # otherwise a new task is created by that name (but not yet saved to the system).
  #
  def initialize(task_name)
    raise TypeError unless task_name.is_a?(String)

    @full_task_path = TaskScheduler2::ROOT_FOLDER + task_name
    @task = TaskScheduler2.task(@full_task_path)
    @definition = @task.nil? ?
      TaskScheduler2.new_task_definition :
      TaskScheduler2.task_definition(@task)
    @task_password = nil

    self.compatibility = TaskScheduler2::TASK_COMPATIBILITY::TASK_COMPATIBILITY_V1
    set_account_information('',nil)
  end

  # Returns an array of scheduled task names.
  #
  def self.tasks
    TaskScheduler2.enum_task_names(TaskScheduler2::ROOT_FOLDER,
      include_child_folders: false,
      include_compatibility: [
        TaskScheduler2::TASK_COMPATIBILITY::TASK_COMPATIBILITY_AT,
        TaskScheduler2::TASK_COMPATIBILITY::TASK_COMPATIBILITY_V1
      ]).map do |item|
        TaskScheduler2.task_name_from_task_path(item)
    end
  end

  # Returns whether or not the scheduled task exists.
  def self.exists?(job_name)
    # task name comparison is case insensitive
    tasks.any? { |name| name.casecmp(job_name) == 0 }
  end

  # Delete the specified task name.
  #
  def self.delete(task_name)
    TaskScheduler2.delete(TaskScheduler2::ROOT_FOLDER + task_name)
  end

  # Saves the current task. Tasks must be saved before they can be activated.
  # The .job file itself is typically stored in the C:\WINDOWS\Tasks folder.
  #
  def save
    task_object = @task.nil? ? @full_task_path : @task
    TaskScheduler2.save(task_object, @definition, @task_password)
  end

  # Sets the +user+ and +password+ for the given task. If the user and
  # password are set properly then true is returned.
  #
  # In some cases the job may be created, but the account information was
  # bad. In this case the task is created but a warning is generated and
  # false is returned.
  #
  # Note that if intending to use SYSTEM, specify an empty user and nil password
  #
  # This must be done prior to the 1st save() call for the task to be
  # properly registered and visible through the MMC snap-in / schtasks.exe
  #
  def set_account_information(user, password)
    @task_password = password
    TaskScheduler2.set_principal(@definition, user)
  end

  # Returns the user associated with the task or nil if no user has yet
  # been associated with the task.
  #
  def account_information
    principal = @definition.Principal
    principal.nil? ? nil : principal.UserId
  end

  # Returns the name of the application associated with the task.
  #
  def application_name
    action = default_action(create_if_missing: false)
    action.nil? ? nil : action.Path
  end

  # Sets the application name associated with the task.
  #
  def application_name=(app)
    action = default_action(create_if_missing: true)
    action.Path = app
    app
  end

  # Returns the command line parameters for the task.
  #
  def parameters
    action = default_action(create_if_missing: false)
    action.nil? ? nil : action.Arguments
  end

  # Sets the parameters for the task. These parameters are passed as command
  # line arguments to the application the task will run. To clear the command
  # line parameters set it to an empty string.
  #
  def parameters=(param)
    action = default_action(create_if_missing: true)
    action.Arguments = param
    param
  end

  # Returns the working directory for the task.
  #
  def working_directory
    action = default_action(create_if_missing: false)
    action.nil? ? nil : action.WorkingDirectory
  end

  # Sets the working directory for the task.
  #
  def working_directory=(dir)
    action = default_action(create_if_missing: false)
    action.WorkingDirectory = dir
    dir
  end

  def compatibility
    @definition.Settings.Compatibility
  end

  def compatibility=(value)
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381846(v=vs.85).aspx
    @definition.Settings.Compatibility = value
  end

  # Returns the number of triggers associated with the active task.
  #
  def trigger_count
    TaskScheduler2.trigger_count(@definition)
  end

  # Deletes the trigger at the specified index.
  #
  def delete_trigger(index)
    # The older V1 API uses a starting index of zero, wherease the V2 API uses one.
    # Need to increment by one to maintain the same behavior
    TaskScheduler2.delete_trigger(@definition, index + 1)
  end

  # Returns a hash that describes the trigger at the given index for the
  # current task.
  #
  def trigger(index)
    # The older V1 API uses a starting index of zero, wherease the V2 API uses one.
    # Need to increment by one to maintain the same behavior
    trigger_object = TaskScheduler2.trigger(@definition, index + 1)
    trigger_object.nil? || Trigger::V2::TYPE_MANIFEST_MAP[trigger_object.Type].nil? ?
      nil :
      Trigger::V2.to_manifest_hash(trigger_object)
  end

  # Appends a new trigger for the currently active task.
  #
  def append_trigger(manifest_hash)
    Trigger::V2.append_trigger(@definition, manifest_hash)
  end

  def enabled
    @definition.Settings.Enabled
  end

  def enabled=(value)
    @definition.Settings.Enabled = value
  end

  private
  # :stopdoc:

  # Find the first TASK_ACTION_EXEC action
  def default_action(create_if_missing: false)
    action = nil
    (1..TaskScheduler2.action_count(@definition)).each do |i|
      index_action = TaskScheduler2.action(@definition, i)
      action = index_action if index_action.Type == TaskScheduler2::TASK_ACTION_TYPE::TASK_ACTION_EXEC
      break if action
    end

    if action.nil? && create_if_missing
      action = TaskScheduler2.create_action(@definition, TaskScheduler2::TASK_ACTION_TYPE::TASK_ACTION_EXEC)
    end

    action
  end
end

end
end
end
