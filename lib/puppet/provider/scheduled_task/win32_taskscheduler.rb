require 'puppet/parameter'
require_relative '../../../puppet_x/puppetlabs/scheduled_task/taskscheduler2_v1task'


Puppet::Type.type(:scheduled_task).provide(:win32_taskscheduler) do
  desc "This provider manages scheduled tasks on Windows.
       This is a technical preview using the newer V2 API interface but
       still editing V1 compatbile scheduled tasks."

  confine    :operatingsystem => :windows

  has_feature :compatibility

  def self.instances
    PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2V1Task.new.tasks.collect do |job_file|
      job_title = File.basename(job_file, '.job')
      new(
        :provider => :win32_taskscheduler,
        :name     => job_title
      )
    end
  end

  def exists?
    PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2V1Task.new.exists? resource[:name]
  end

  def task
    return @task if @task

    @task ||= PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2V1Task.new
    @task.activate(resource[:name] + '.job') if exists?

    @task
  end

  def clear_task
    @task       = nil
    @triggers   = nil
  end

  def enabled
    task.flags & PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_FLAG_DISABLED == 0 ? :true : :false
  end

  def command
    task.application_name
  end

  def arguments
    task.parameters
  end

  def working_dir
    task.working_directory
  end

  def user
    account = task.account_information
    return 'system' if account == ''
    account
  end

  def compatibility
    task.compatibility
  end

  def trigger
    @triggers ||= task.trigger_count.times.map do |i|
      v1trigger = task.trigger(i)
      # nil trigger definitions are unsupported ITrigger types
      next if v1trigger.nil?
      index = { 'index' => i }
      PuppetX::PuppetLabs::ScheduledTask::Trigger::V1.to_manifest_hash(v1trigger).merge(index)
    end.compact
  end

  def user_insync?(current, should)
    return false unless current

    # Win32::TaskScheduler can return the 'SYSTEM' account as the
    # empty string.
    current = 'system' if current == ''

    # By comparing account SIDs we don't have to worry about case
    # sensitivity, or canonicalization of the account name.
    Puppet::Util::Windows::SID.name_to_sid(current) == Puppet::Util::Windows::SID.name_to_sid(should[0])
  end

  def trigger_insync?(current, should)
    should  = [should] unless should.is_a?(Array)
    current = [current] unless current.is_a?(Array)
    return false unless current.length == should.length

    current_in_sync = current.all? do |c|
      should.any? {|s| triggers_same?(c, s)}
    end

    should_in_sync = should.all? do |s|
      current.any? {|c| triggers_same?(c,s)}
    end

    current_in_sync && should_in_sync
  end

  def command=(value)
    task.application_name = value
  end

  def arguments=(value)
    task.parameters = value
  end

  def working_dir=(value)
    task.working_directory = value
  end

  def enabled=(value)
    if value == :true
      task.flags = task.flags & ~PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_FLAG_DISABLED
    else
      task.flags = task.flags | PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2::TASK_FLAG_DISABLED
    end
  end

  def compatibility=(value)
    task.compatibility = value
  end

  def trigger=(value)
    desired_triggers = value.is_a?(Array) ? value : [value]
    current_triggers = trigger.is_a?(Array) ? trigger : [trigger]

    extra_triggers = []
    desired_to_search = desired_triggers.dup
    current_triggers.each do |current|
      if found = desired_to_search.find {|desired| triggers_same?(current, desired)}
        desired_to_search.delete(found)
      else
        extra_triggers << current['index']
      end
    end

    needed_triggers = []
    current_to_search = current_triggers.dup
    desired_triggers.each do |desired|
      if found = current_to_search.find {|current| triggers_same?(current, desired)}
        current_to_search.delete(found)
      else
        needed_triggers << desired
      end
    end

    extra_triggers.reverse_each do |index|
      task.delete_trigger(index)
    end

    needed_triggers.each do |trigger_hash|
      v1trigger = PuppetX::PuppetLabs::ScheduledTask::Trigger::V1.from_manifest_hash(trigger_hash)
      task.append_trigger(v1trigger)
    end
  end

  def user=(value)
    self.fail("Invalid user: #{value}") unless Puppet::Util::Windows::SID.name_to_sid(value)

    if value.to_s.downcase != 'system'
      task.set_account_information(value, resource[:password])
    else
      # Win32::TaskScheduler treats a nil/empty username & password as
      # requesting the SYSTEM account.
      task.set_account_information(nil, nil)
    end
  end

  def create
    clear_task
    @task = PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2V1Task.new(
      resource[:name],
      PuppetX::PuppetLabs::ScheduledTask::Trigger::V1.default_trigger_for('once')
    )
    self.command = resource[:command]

    [:arguments, :working_dir, :enabled, :trigger, :user].each do |prop|
      send("#{prop}=", resource[prop]) if resource[prop]
    end
  end

  def destroy
    PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2V1Task.new.delete(resource[:name] + '.job')
  end

  def flush
    unless resource[:ensure] == :absent
      self.fail('Parameter command is required.') unless resource[:command]
      # HACK: even though the user may actually be insync?, for task changes to
      # fully propagate, it is necessary to explicitly set the user for the task,
      # even when it is SYSTEM (and has a nil password)
      # this is a Windows security feature with the v1 COM APIs that prevent
      # arbitrary reassignment of a task scheduler command to run as SYSTEM
      # without the authorization to do so
      self.user = resource[:user]
      task.save
      @task = nil
    end
  end

  def triggers_same?(current_trigger, desired_trigger)
    return false unless current_trigger['schedule'] == desired_trigger['schedule']
    return false if current_trigger.has_key?('enabled') && !current_trigger['enabled']
    return false if PuppetX::PuppetLabs::ScheduledTask::Trigger::V1.from_manifest_hash(desired_trigger)['trigger_type'] != PuppetX::PuppetLabs::ScheduledTask::Trigger::V1.from_manifest_hash(current_trigger)['trigger_type']

    desired = desired_trigger.dup
    desired['start_date']  ||= current_trigger['start_date']  if current_trigger.has_key?('start_date')
    desired['every']       ||= current_trigger['every']       if current_trigger.has_key?('every')
    desired['months']      ||= current_trigger['months']      if current_trigger.has_key?('months')
    desired['on']          ||= current_trigger['on']          if current_trigger.has_key?('on')
    desired['day_of_week'] ||= current_trigger['day_of_week'] if current_trigger.has_key?('day_of_week')

    PuppetX::PuppetLabs::ScheduledTask::Trigger::V1.from_manifest_hash(current_trigger) == PuppetX::PuppetLabs::ScheduledTask::Trigger::V1.from_manifest_hash(desired)
  end

  def validate_trigger(value)
    [value].flatten.each do |t|
      %w[index enabled].each do |key|
        if t.key?(key)
          self.fail "'#{key}' is read-only on scheduled_task triggers and should be removed ('#{key}' is usually provided in puppet resource scheduled_task)."
        end
      end
      PuppetX::PuppetLabs::ScheduledTask::Trigger::V1.from_manifest_hash(t)
    end

    true
  end
end
