# This class is used to manage V1 compatible tasks using the Task Scheduler V2 API
# It is designed to be a binary compatible API to puppet/util/windows/taskscheduler.rb but
# will only surface the features used by the Puppet scheduledtask provider
#
require_relative './taskscheduler2'
require_relative './trigger'

module PuppetX
module PuppetLabs
module ScheduledTask

class TaskScheduler2V1Task
  # The error class raised if any task scheduler specific calls fail.
  class Error < Puppet::Util::Windows::Error; end

  public
  # Returns a new TaskScheduler object. If a work_item (and possibly the
  # the trigger) are passed as arguments then a new work item is created and
  # associated with that trigger, although you can still activate other tasks
  # with the same handle.
  #
  # This is really just a bit of convenience. Passing arguments to the
  # constructor is the same as calling TaskScheduler.new plus
  # TaskScheduler#new_work_item.
  #
  def initialize(work_item = nil, trigger = nil)
    @tasksched = PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2

    new_work_item(work_item, trigger) if work_item && trigger
  end

  # Returns an array of scheduled task names.
  #
  # Emulates V1 tasks by appending the '.job' suffix
  #
  def enum
    @tasksched.enum_task_names(PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::ROOT_FOLDER,
      include_child_folders: false,
      include_compatibility: [PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_COMPATIBILITY_AT, PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_COMPATIBILITY_V1]).map do |item|
        @tasksched.task_name_from_task_path(item) + '.job'
    end
  end
  alias :tasks :enum

  # Activate the specified task.
  #
  def activate(task_name)
    raise TypeError unless task_name.is_a?(String)
    normal_task_name = normalize_task_name(task_name)
    raise Error.new(_("Scheduled Task %{task_name} does not exist") % { task_name: normal_task_name }) unless exists?(normal_task_name)

    full_taskname = PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::ROOT_FOLDER + normal_task_name

    @task = @tasksched.task(full_taskname)
    @full_task_path = full_taskname
    @definition = @tasksched.task_definition(@task)
    @task_password = nil

    @task
  end

  # Delete the specified task name.
  #
  def delete(task_name)
    full_taskname = PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::ROOT_FOLDER + normalize_task_name(task_name)
    @tasksched.delete(full_taskname)
  end

  # Saves the current task. Tasks must be saved before they can be activated.
  # The .job file itself is typically stored in the C:\WINDOWS\Tasks folder.
  #
  # If +file+ (an absolute path) is specified then the job is saved to that
  # file instead. A '.job' extension is recommended but not enforced.
  #
  def save(file = nil)
    task_object = @task.nil? ? @full_task_path : @task
    @tasksched.save(task_object, @definition, @task_password)
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
  # task.flags = Win32::TaskScheduler::TASK_FLAG_RUN_ONLY_IF_LOGGED_ON
  #
  # This must be done prior to the 1st save() call for the task to be
  # properly registered and visible through the MMC snap-in / schtasks.exe
  #
  def set_account_information(user, password)
    @task_password = password
    @tasksched.set_principal(@definition, user)
  end

  # Returns the user associated with the task or nil if no user has yet
  # been associated with the task.
  #
  def account_information
    principal = @tasksched.principal(@definition)
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

  # Creates a new work item (scheduled job) with the given +trigger+. The
  # trigger variable is a hash of options that define when the scheduled
  # job should run.
  #
  def new_work_item(task_name, task_trigger)
    raise TypeError unless task_trigger.is_a?(Hash)

    @full_task_path = PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::ROOT_FOLDER + normalize_task_name(task_name)
    @definition = @tasksched.new_task_definition
    @task = nil
    @task_password = nil

    @tasksched.set_compatibility(@definition, PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_COMPATIBILITY_V1)

    append_trigger(task_trigger)

    set_account_information('',nil)

    @definition
  end
  alias :new_task :new_work_item

  # Returns the number of triggers associated with the active task.
  #
  def trigger_count
    @tasksched.trigger_count(@definition)
  end

  # Deletes the trigger at the specified index.
  #
  def delete_trigger(index)
    # The older V1 API uses a starting index of zero, wherease the V2 API uses one.
    # Need to increment by one to maintain the same behavior
    @tasksched.delete_trigger(@definition, index + 1)
  end

  # Returns a hash that describes the trigger at the given index for the
  # current task.
  #
  def trigger(index)
    # The older V1 API uses a starting index of zero, wherease the V2 API uses one.
    # Need to increment by one to maintain the same behavior
    trigger_object = @tasksched.trigger(@definition, index + 1)
    trigger_object.nil? ? nil : Trigger::V1.from_v2trigger(trigger_object)
  end

  # Sets the trigger for the currently active task.
  #
  # Note - This method name is a mis-nomer. It's actually appending a newly created trigger to the trigger collection.
  def trigger=(v1trigger)
    append_trigger(v1trigger)
  end

  # Returns the flags (integer) that modify the behavior of the work item. You
  # must OR the return value to determine the flags yourself.
  #
  def flags
    flags = 0
    flags = flags | Win32::TaskScheduler::DISABLED if !@definition.Settings.Enabled
    flags
  end

  # Sets an OR'd value of flags that modify the behavior of the work item.
  #
  def flags=(flags)
    @definition.Settings.Enabled = (flags & Win32::TaskScheduler::DISABLED == 0)
  end

  # Returns whether or not the scheduled task exists.
  def exists?(job_name)
    # task name comparison is case insensitive
    enum.any? { |name| name.casecmp(job_name + '.job') == 0 }
  end

  private
  # :stopdoc:

  def normalize_task_name(task_name)
    # The Puppet provider and some other instances may pass a '.job' suffix as per the V1 API
    # This is not needed for the V2 API so we just remove it
    task_name = task_name.slice(0,task_name.length - 4) if task_name.end_with?('.job')

    task_name
  end

  # Find the first TASK_ACTION_EXEC action
  def default_action(create_if_missing: false)
    action = nil
    (1..@tasksched.action_count(@definition)).each do |i|
      index_action = @tasksched.action(@definition, i)
      action = index_action if index_action.Type == PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_ACTION_EXEC
      break if action
    end

    if action.nil? && create_if_missing
      action = @tasksched.create_action(@definition, PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_ACTION_EXEC)
    end

    action
  end

  # Used for validating a trigger hash from Puppet
  ValidTriggerKeys = [
    'end_day',
    'end_month',
    'end_year',
    'flags',
    'minutes_duration',
    'minutes_interval',
    'random_minutes_interval',
    'start_day',
    'start_hour',
    'start_minute',
    'start_month',
    'start_year',
    'trigger_type',
    'type'
  ]

  ValidTypeKeys = [
      'days_interval',
      'weeks_interval',
      'days_of_week',
      'months',
      'days',
      'weeks'
  ]

  # Private method that validates keys, and converts all keys to lowercase
  # strings.
  #
  def transform_and_validate(hash)
    new_hash = {}

    hash.each do |key, value|
      key = key.to_s.downcase
      if key == 'type'
        new_type_hash = {}
        raise ArgumentError unless value.is_a?(Hash)
        value.each{ |subkey, subvalue|
          subkey = subkey.to_s.downcase
          if ValidTypeKeys.include?(subkey)
            new_type_hash[subkey] = subvalue
          else
            raise ArgumentError, "Invalid type key '#{subkey}'"
          end
        }
        new_hash[key] = new_type_hash
      else
        if ValidTriggerKeys.include?(key)
          new_hash[key] = value
        else
          raise ArgumentError, "Invalid key '#{key}'"
        end
      end
    end

    new_hash
  end

  def append_trigger(v1trigger)
    raise TypeError unless v1trigger.is_a?(Hash)
    v1trigger = transform_and_validate(v1trigger)

    trigger_object = nil
    trigger_settings = v1trigger['type']

    case v1trigger['trigger_type']
      when :TASK_TIME_TRIGGER_DAILY
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446858(v=vs.85).aspx
        trigger_object = @tasksched.append_new_trigger(@definition, PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_TRIGGER_DAILY)
        trigger_object.DaysInterval = trigger_settings['days_interval']
        # Static V2 settings which are not set by the Puppet scheduledtask type
        trigger_object.Randomdelay = 0

      when :TASK_TIME_TRIGGER_WEEKLY
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384019(v=vs.85).aspx
        trigger_object = @tasksched.append_new_trigger(@definition, PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_TRIGGER_WEEKLY)
        trigger_object.DaysOfWeek = trigger_settings['days_of_week']
        trigger_object.WeeksInterval = trigger_settings['weeks_interval']
        # Static V2 settings which are not set by the Puppet scheduledtask type
        trigger_object.Randomdelay = 0

      when :TASK_TIME_TRIGGER_MONTHLYDATE
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382062(v=vs.85).aspx
        trigger_object = @tasksched.append_new_trigger(@definition, PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_TRIGGER_MONTHLY)
        trigger_object.DaysOfMonth = trigger_settings['days']
        trigger_object.Monthsofyear = trigger_settings['months']
        # Static V2 settings which are not set by the Puppet scheduledtask type
        trigger_object.RunOnLastDayOfMonth = false
        trigger_object.Randomdelay = 0

      when :TASK_TIME_TRIGGER_MONTHLYDOW
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382055(v=vs.85).aspx
        trigger_object = @tasksched.append_new_trigger(@definition, PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_TRIGGER_MONTHLYDOW)
        trigger_object.DaysOfWeek = trigger_settings['days_of_week']
        trigger_object.Monthsofyear = trigger_settings['months']
        trigger_object.Weeksofmonth = trigger_settings['weeks']
        # Static V2 settings which are not set by the Puppet scheduledtask type
        trigger_object.RunonLastWeekOfMonth = false
        trigger_object.Randomdelay = 0

      when :TASK_TIME_TRIGGER_ONCE
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383622(v=vs.85).aspx
        trigger_object = @tasksched.append_new_trigger(@definition, PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_TRIGGER_TIME)
        # Static V2 settings which are not set by the Puppet scheduledtask type
        trigger_object.Randomdelay = 0
      else
        raise Error.new(_("Unknown V1 trigger type %{type}") % { type: v1trigger['trigger_type'] })
    end

    # Values for all Trigger Types
    trigger_object.Repetition.Interval = "PT#{v1trigger['minutes_interval']}M" unless v1trigger['minutes_interval'].nil? || v1trigger['minutes_interval'].zero?
    trigger_object.Repetition.Duration = "PT#{v1trigger['minutes_duration']}M" unless v1trigger['minutes_duration'].nil? || v1trigger['minutes_duration'].zero?
    trigger_object.StartBoundary = Trigger.iso8601_datetime(v1trigger['start_year'],
                                                            v1trigger['start_month'],
                                                            v1trigger['start_day'],
                                                            v1trigger['start_hour'],
                                                            v1trigger['start_minute']
    )
    # Static V2 settings which are not set by the Puppet scheduledtask type
    trigger_object.Repetition.StopAtDurationEnd = false

    v1trigger
  end
end

end
end
end
