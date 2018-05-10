# This class is used to manage V1 compatible tasks using the Task Scheduler V2 API
require_relative './taskscheduler2'
require_relative './trigger'

module PuppetX
module PuppetLabs
module ScheduledTask

class V2Adapter
  public
  # Returns a new TaskScheduler object. If a task_name is passed as an argument
  # an existing task will be returned if one exists, otherwise a new task is
  # created by that name (but is not yet saved to the system).
  #
  def initialize(task_name = nil)
    raise TypeError unless task_name.nil? || task_name.is_a?(String)

    if task_name
      @full_task_path = TaskScheduler2::ROOT_FOLDER + task_name
    end

    @task = task_name && self.class.exists?(task_name) ?
      TaskScheduler2.task(@full_task_path) :
      nil

    @definition = @task.nil? ?
      TaskScheduler2.new_task_definition :
      TaskScheduler2.task_definition(@task)
    @task_password = nil

    set_account_information('',nil)
  end

  # Returns an array of scheduled task names.
  #
  def self.tasks
    TaskScheduler2.enum_task_names(TaskScheduler2::ROOT_FOLDER,
      include_child_folders: false,
      include_compatibility: [
        TaskScheduler2::TASK_COMPATIBILITY_V6,
        TaskScheduler2::TASK_COMPATIBILITY_V4,
        TaskScheduler2::TASK_COMPATIBILITY_V3,
        TaskScheduler2::TASK_COMPATIBILITY_V2,
        TaskScheduler2::TASK_COMPATIBILITY_AT,
        TaskScheduler2::TASK_COMPATIBILITY_V1
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
  # Calling task.set_account_information('SYSTEM', nil) will generally not
  # work, except for one special case where flags are also set like:
  # task.flags = TaskScheduler2::TASK_FLAG_RUN_ONLY_IF_LOGGED_ON
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
    principal = TaskScheduler2.principal(@definition)
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

  # Returns the number of triggers associated with the active task.
  #
  def trigger_count
    TaskScheduler2.trigger_count(@definition)
  end

  def compatibility
    TaskScheduler2.compatibility(@definition)
  end

  def compatibility=(value)
    TaskScheduler2.set_compatibility(@definition, value)
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
    trigger_object.nil? || Trigger::V2::V1_TYPE_MAP.key(trigger_object.Type).nil? ?
      nil :
      Trigger::V1.from_iTrigger(trigger_object)
  end

  # Appends a new trigger for the currently active task.
  #
  def append_trigger(v1trigger)
    Trigger::V2.append_v1trigger(@definition, v1trigger)
  end

  # Returns the flags (integer) that modify the behavior of the work item. You
  # must OR the return value to determine the flags yourself.
  #
  def flags
    flags = 0
    flags = flags | TaskScheduler2::TASK_FLAG_DISABLED if !@definition.Settings.Enabled
    flags
  end

  # Sets an OR'd value of flags that modify the behavior of the work item.
  #
  def flags=(flags)
    @definition.Settings.Enabled = (flags & TaskScheduler2::TASK_FLAG_DISABLED == 0)
  end

  private
  # :stopdoc:

  # Find the first TASK_ACTION_EXEC action
  def default_action(create_if_missing: false)
    action = nil
    (1..TaskScheduler2.action_count(@definition)).each do |i|
      index_action = TaskScheduler2.action(@definition, i)
      action = index_action if index_action.Type == TaskScheduler2::TASK_ACTION_EXEC
      break if action
    end

    if action.nil? && create_if_missing
      action = TaskScheduler2.create_action(@definition, TaskScheduler2::TASK_ACTION_EXEC)
    end

    action
  end
end

end
end
end
