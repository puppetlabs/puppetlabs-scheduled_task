# The TaskScheduler2 class encapsulates taskscheduler settings and behavior using the v2 API
# https://msdn.microsoft.com/en-us/library/windows/desktop/aa383600(v=vs.85).aspx

# @api private
module PuppetX
module PuppetLabs
module ScheduledTask

module TaskScheduler2
  # The name of the root folder for tasks
  ROOT_FOLDER = '\\'.freeze

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383558(v=vs.85).aspx
  TASK_ENUM_HIDDEN  = 0x1

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_action_type
  class TASK_ACTION_TYPE
    TASK_ACTION_EXEC          = 0
    TASK_ACTION_COM_HANDLER   = 5
    TASK_ACTION_SEND_EMAIL    = 6
    TASK_ACTION_SHOW_MESSAGE  = 7
  end

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383557(v=vs.85).aspx
  # Undocumented values
  # Win7/2008 R2                       = 3
  # Win8/Server 2012 R2 or Server 2016 = 4
  # Windows 10                         = 5 / 6
  TASK_COMPATIBILITY_AT = 0
  TASK_COMPATIBILITY_V1 = 1
  TASK_COMPATIBILITY_V2 = 2
  TASK_COMPATIBILITY_V2_1 = 3
  TASK_COMPATIBILITY_V2_2 = 4
  TASK_COMPATIBILITY_V2_3 = 5
  TASK_COMPATIBILITY_V2_4 = 6

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382538%28v=vs.85%29.aspx
  TASK_VALIDATE_ONLY                 = 0x1
  TASK_CREATE                        = 0x2
  TASK_UPDATE                        = 0x4
  TASK_CREATE_OR_UPDATE              = 0x6
  TASK_DISABLE                       = 0x8
  TASK_DONT_ADD_PRINCIPAL_ACE        = 0x10
  TASK_IGNORE_REGISTRATION_TRIGGERS  = 0x20

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383566(v=vs.85).aspx
  TASK_LOGON_NONE                           = 0
  TASK_LOGON_PASSWORD                       = 1
  TASK_LOGON_S4U                            = 2
  TASK_LOGON_INTERACTIVE_TOKEN              = 3
  TASK_LOGON_GROUP                          = 4
  TASK_LOGON_SERVICE_ACCOUNT                = 5
  TASK_LOGON_INTERACTIVE_TOKEN_OR_PASSWORD  = 6

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380747(v=vs.85).aspx
  TASK_RUNLEVEL_LUA     = 0
  TASK_RUNLEVEL_HIGHEST = 1

  RESERVED_FOR_FUTURE_USE = 0

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381283(v=vs.85).aspx
  TASK_FLAG_INTERACTIVE                  = 0x1
  TASK_FLAG_DELETE_WHEN_DONE             = 0x2
  TASK_FLAG_DISABLED                     = 0x4
  TASK_FLAG_START_ONLY_IF_IDLE           = 0x10
  TASK_FLAG_KILL_ON_IDLE_END             = 0x20
  TASK_FLAG_DONT_START_IF_ON_BATTERIES   = 0x40
  TASK_FLAG_KILL_IF_GOING_ON_BATTERIES   = 0x80
  TASK_FLAG_RUN_ONLY_IF_DOCKED           = 0x100
  TASK_FLAG_HIDDEN                       = 0x200
  TASK_FLAG_RUN_IF_CONNECTED_TO_INTERNET = 0x400
  TASK_FLAG_RESTART_ON_IDLE_RESUME       = 0x800
  TASK_FLAG_SYSTEM_REQUIRED              = 0x1000
  TASK_FLAG_RUN_ONLY_IF_LOGGED_ON        = 0x2000

  def self.folder_path_from_task_path(task_path)
    path = task_path.rpartition('\\')[0]

    path.empty? ? ROOT_FOLDER : path
  end

  def self.task_name_from_task_path(task_path)
    task_path.rpartition('\\')[2]
  end

  # Returns an array of scheduled task names.
  # By default EVERYTHING is enumerated
  # option hash
  #    include_child_folders: recurses into child folders for tasks. Default true
  #    include_compatibility: Only include tasks which have any of the specified compatibility levels. Default empty array (everything is permitted)
  #
  def self.enum_task_names(folder_path = ROOT_FOLDER, enum_options = {})
    raise TypeError unless folder_path.is_a?(String)

    options = {
      :include_child_folders => true,
      :include_compatibility => [],
    }.merge(enum_options)

    array = []

    task_folder = task_service.GetFolder(folder_path)
    filter_compatibility = !options[:include_compatibility].empty?
    task_folder.GetTasks(TASK_ENUM_HIDDEN).each do |task|
      next if filter_compatibility && !options[:include_compatibility].include?(task.Definition.Settings.Compatibility)
      array << task.Path
    end
    return array unless options[:include_child_folders]

    task_folder.GetFolders(RESERVED_FOR_FUTURE_USE).each do |child_folder|
      array += enum_task_names(child_folder.Path, options)
    end

    array
  end

  def self.task(task_path)
    raise TypeError unless task_path.is_a?(String)
    begin
      task_folder = task_service.GetFolder(folder_path_from_task_path(task_path))
      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381363(v=vs.85).aspx
      return task_folder.GetTask(task_name_from_task_path(task_path))
    rescue WIN32OLERuntimeError => e
      # ERROR_FILE_NOT_FOUND 2L from winerror.h becomes this in COM
      unless e.message =~ /80070002/m
        raise Puppet::Error.new( _("GetTask failed with: %{error}") % { error: e }, e )
      end
    end

    nil
  end

  def self.new_task_definition
    task_service.NewTask(0)
  end

  def self.task_definition(task)
    definition = task_service.NewTask(0)
    definition.XmlText = task.XML

    definition
  end

  # Creates or Updates an existing task with the supplied task definition
  # If task_object is a string then this is a new task and the supplied object is the new task's full path
  # Otherwise we expect a Win32OLE Task object to be passed through
  def self.save(task_object, definition, password = nil)
    task_path = task_object.is_a?(String) ? task_object : task_object.Path

    task_folder = task_service.GetFolder(folder_path_from_task_path(task_path))
    task_user = nil
    task_password = nil

    case definition.Principal.LogonType
      when TASK_LOGON_PASSWORD, TASK_LOGON_INTERACTIVE_TOKEN_OR_PASSWORD
        task_user = definition.Principal.UserId
        task_password = password
    end
    task_folder.RegisterTaskDefinition(task_name_from_task_path(task_path),
                                       definition, TASK_CREATE_OR_UPDATE, task_user, task_password,
                                       definition.Principal.LogonType)
  end

  # Delete the specified task name.
  #
  def self.delete(task_path)
    raise TypeError unless task_path.is_a?(String)
    task_folder = task_service.GetFolder(folder_path_from_task_path(task_path))

    task_folder.DeleteTask(task_name_from_task_path(task_path),0)
  end

  # General Properties
  def self.principal(definition)
    definition.Principal
  end

  def self.set_principal(definition, user)
    if (user.nil? || user == "")
      # Setup for the local system account
      definition.Principal.UserId = 'SYSTEM'
      definition.Principal.LogonType = TASK_LOGON_SERVICE_ACCOUNT
      definition.Principal.RunLevel = TASK_RUNLEVEL_HIGHEST
      return true
    else
      definition.Principal.UserId = user
      definition.Principal.LogonType = TASK_LOGON_PASSWORD
      definition.Principal.RunLevel = TASK_RUNLEVEL_HIGHEST
      return true
    end
  end

  # Returns the compatibility level of the task.
  #
  def self.compatibility(definition)
    definition.Settings.Compatibility
  end

  # Sets the compatibility with the task.
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381846(v=vs.85).aspx
  #
  def self.set_compatibility(definition, value)
    definition.Settings.Compatibility = value
  end

  # Task Actions
  # Returns the number of actions associated with the active task.
  #
  def self.action_count(definition)
    definition.Actions.count
  end

  def self.action(definition, index)
    result = nil

    begin
      result = definition.Actions.Item(index)
    rescue WIN32OLERuntimeError => err
      # E_INVALIDARG 0x80070057 from # https://msdn.microsoft.com/en-us/library/windows/desktop/aa378137%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396
      if err.message =~ /80070057/m
        result = nil
      else
        raise
      end
    end

    result
  end

  def self.create_action(definition, action_type)
    definition.Actions.Create(action_type)
  end

  # Task Triggers
  def self.trigger_count(definition)
    definition.Triggers.count
  end

  # Returns a Win32OLE Trigger Object for the trigger at the given index for the
  # supplied definition.
  #
  # Returns nil if the index does not exist
  #
  # Note - This is a 1 based array (not zero)
  #
  def self.trigger(definition, index)
    result = nil

    begin
      result = definition.Triggers.Item(index)
    rescue WIN32OLERuntimeError => err
      # E_INVALIDARG 0x80070057 from # https://msdn.microsoft.com/en-us/library/windows/desktop/aa378137%28v=vs.85%29.aspx?f=255&MSPPError=-2147217396
      if err.message =~ /80070057/m
        result = nil
      else
        raise
      end
    end

    result
  end

  # Deletes the trigger at the specified index.
  #
  def self.delete_trigger(definition, index)
    definition.Triggers.Remove(index)

    index
  end

  # Private methods
  def self.task_service
    service = WIN32OLE.new('Schedule.Service')
    service.connect()

    service
  end
  private_class_method :task_service
end

end
end
end
