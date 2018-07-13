# The TaskScheduler2 class encapsulates taskscheduler settings and behavior using the v2 API
# https://msdn.microsoft.com/en-us/library/windows/desktop/aa383600(v=vs.85).aspx

require_relative './error'

# @api private
module PuppetX
module PuppetLabs
module ScheduledTask

module TaskScheduler2
  # The name of the root folder for tasks
  ROOT_FOLDER = '\\'.freeze

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_enum_flags
  class TASK_ENUM_FLAGS
    TASK_ENUM_HIDDEN  = 0x1
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_action_type
  class TASK_ACTION_TYPE
    TASK_ACTION_EXEC          = 0
    TASK_ACTION_COM_HANDLER   = 5
    TASK_ACTION_SEND_EMAIL    = 6
    TASK_ACTION_SHOW_MESSAGE  = 7
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_compatibility
  # Win7/2008 R2                       = 3
  # Win8/Server 2012 R2 or Server 2016 = 4
  # Windows 10                         = 5 / 6
  class TASK_COMPATIBILITY
    TASK_COMPATIBILITY_AT     = 0
    TASK_COMPATIBILITY_V1     = 1
    TASK_COMPATIBILITY_V2     = 2
    TASK_COMPATIBILITY_V2_1   = 3
    TASK_COMPATIBILITY_V2_2   = 4
    TASK_COMPATIBILITY_V2_3   = 5
    TASK_COMPATIBILITY_V2_4   = 6
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_creation
  class TASK_CREATION
    TASK_VALIDATE_ONLY                 = 0x1
    TASK_CREATE                        = 0x2
    TASK_UPDATE                        = 0x4
    # ( TASK_CREATE | TASK_UPDATE )
    TASK_CREATE_OR_UPDATE              = 0x6
    TASK_DISABLE                       = 0x8
    TASK_DONT_ADD_PRINCIPAL_ACE        = 0x10
    TASK_IGNORE_REGISTRATION_TRIGGERS  = 0x20
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_logon_type
  class TASK_LOGON_TYPE
    TASK_LOGON_NONE                           = 0
    TASK_LOGON_PASSWORD                       = 1
    TASK_LOGON_S4U                            = 2
    TASK_LOGON_INTERACTIVE_TOKEN              = 3
    TASK_LOGON_GROUP                          = 4
    TASK_LOGON_SERVICE_ACCOUNT                = 5
    TASK_LOGON_INTERACTIVE_TOKEN_OR_PASSWORD  = 6
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_run_flags
  class TASK_RUN_FLAGS
    TASK_RUN_NO_FLAGS             = 0
    TASK_RUN_AS_SELF              = 0x1
    TASK_RUN_IGNORE_CONSTRAINTS   = 0x2
    TASK_RUN_USE_SESSION_ID       = 0x4
    TASK_RUN_USER_SID             = 0x8
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_runlevel
  class TASK_RUNLEVEL_TYPE
    TASK_RUNLEVEL_LUA     = 0
    TASK_RUNLEVEL_HIGHEST = 1
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_processtokensid
  class TASK_PROCESSTOKENSID_TYPE
    TASK_PROCESSTOKENSID_NONE           = 0
    TASK_PROCESSTOKENSID_UNRESTRICTED   = 1
    TASK_PROCESSTOKENSID_DEFAULT        = 2
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_state
  class TASK_STATE
    TASK_STATE_UNKNOWN    = 0
    TASK_STATE_DISABLED   = 1
    TASK_STATE_QUEUED     = 2
    TASK_STATE_READY      = 3
    TASK_STATE_RUNNING    = 4
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_instances_policy
  class TASK_INSTANCES_POLICY
    TASK_INSTANCES_PARALLEL       = 0
    TASK_INSTANCES_QUEUE          = 1
    TASK_INSTANCES_IGNORE_NEW     = 2
    TASK_INSTANCES_STOP_EXISTING  = 3
  end

  def self.task_name_from_task_path(task_path)
    task_path.rpartition('\\')[2]
  end

  def self.task(task_path)
    raise TypeError unless task_path.is_a?(String)
    service = task_service
    begin
      task_folder = service.GetFolder(folder_path_from_task_path(task_path))
      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381363(v=vs.85).aspx
      _task = task_folder.GetTask(task_name_from_task_path(task_path))
      return _task, task_definition(_task)
    rescue WIN32OLERuntimeError => e
      unless Error.is_com_error_type(e, Error::ERROR_FILE_NOT_FOUND)
        raise Puppet::Error.new( _("GetTask failed with: %{error}") % { error: e }, e )
      end
    end

    return nil, service.NewTask(0)
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
      when TASK_LOGON_TYPE::TASK_LOGON_PASSWORD, TASK_LOGON_TYPE::TASK_LOGON_INTERACTIVE_TOKEN_OR_PASSWORD
        task_user = definition.Principal.UserId
        task_password = password
    end
    task_folder.RegisterTaskDefinition(task_name_from_task_path(task_path),
                                       definition, TASK_CREATION::TASK_CREATE_OR_UPDATE, task_user, task_password,
                                       definition.Principal.LogonType)
  end

  # Private methods
  def self.task_service
    service = WIN32OLE.new('Schedule.Service')
    service.connect()

    service
  end
  private_class_method :task_service

  def self.task_definition(task)
    definition = task_service.NewTask(0)
    definition.XmlText = task.XML

    definition
  end
  private_class_method :task_definition

  def self.folder_path_from_task_path(task_path)
    path = task_path.rpartition('\\')[0]

    path.empty? ? ROOT_FOLDER : path
  end
  private_class_method :folder_path_from_task_path
end

end
end
end
