require 'puppet/parameter'

if Puppet.features.microsoft_windows?
  require File.join(File.dirname(__FILE__), '../../../puppet_x/puppetlabs/scheduled_task/taskscheduler2_v1task')
end
require File.join(File.dirname(__FILE__), '../../../puppet_x/puppetlabs/scheduled_task/trigger')


Puppet::Type.type(:scheduled_task).provide(:taskscheduler_api2) do
  desc "This provider manages scheduled tasks on Windows.
       This is a technical preview using the newer V2 API interface but
       still editing V1 compatbile scheduled tasks."

  defaultfor :operatingsystem => :windows
  confine    :operatingsystem => :windows

  def self.instances
    PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2V1Task.new.tasks.collect do |job_file|
      job_title = File.basename(job_file, '.job')
      new(
        :provider => :taskscheduler_api2,
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
    task.flags & Win32::TaskScheduler::DISABLED == 0 ? :true : :false
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
    return @triggers if @triggers

    @triggers   = []
    task.trigger_count.times do |i|
      trigger = begin
                  task.trigger(i)
                rescue Win32::TaskScheduler::Error
                  # Win32::TaskScheduler can't handle all of the
                  # trigger types Windows uses, so we need to skip the
                  # unhandled types to prevent "puppet resource" from
                  # blowing up.
                  nil
                end
      next unless trigger and scheduler_trigger_types.include?(trigger['trigger_type'])

      puppet_trigger = {}
      case trigger['trigger_type']
      when Win32::TaskScheduler::TASK_TIME_TRIGGER_DAILY
        puppet_trigger['schedule'] = 'daily'
        puppet_trigger['every']    = trigger['type']['days_interval'].to_s
      when Win32::TaskScheduler::TASK_TIME_TRIGGER_WEEKLY
        puppet_trigger['schedule']    = 'weekly'
        puppet_trigger['every']       = trigger['type']['weeks_interval'].to_s
        puppet_trigger['day_of_week'] = PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Day.bitmask_to_names(trigger['type']['days_of_week'])
      when Win32::TaskScheduler::TASK_TIME_TRIGGER_MONTHLYDATE
        puppet_trigger['schedule'] = 'monthly'
        puppet_trigger['months']   = PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Month.bitmask_to_indexes(trigger['type']['months'])
        puppet_trigger['on']       = PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Days.bitmask_to_indexes(trigger['type']['days'])
      when Win32::TaskScheduler::TASK_TIME_TRIGGER_MONTHLYDOW
        puppet_trigger['schedule']         = 'monthly'
        puppet_trigger['months']           = PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Month.bitmask_to_indexes(trigger['type']['months'])
        puppet_trigger['which_occurrence'] = PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Occurrence.constant_to_name(trigger['type']['weeks'])
        puppet_trigger['day_of_week']      = PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Day.bitmask_to_names(trigger['type']['days_of_week'])
      when Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE
        puppet_trigger['schedule'] = 'once'
      end
      puppet_trigger['start_date'] = self.class.normalized_date("#{trigger['start_year']}-#{trigger['start_month']}-#{trigger['start_day']}")
      puppet_trigger['start_time'] = self.class.normalized_time("#{trigger['start_hour']}:#{trigger['start_minute']}")
      puppet_trigger['enabled']    = trigger['flags'] & Win32::TaskScheduler::TASK_TRIGGER_FLAG_DISABLED == 0
      puppet_trigger['minutes_interval'] = trigger['minutes_interval'] ||= 0
      puppet_trigger['minutes_duration'] = trigger['minutes_duration'] ||= 0
      puppet_trigger['index']      = i

      @triggers << puppet_trigger
    end

    @triggers
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
      task.flags = task.flags & ~Win32::TaskScheduler::DISABLED
    else
      task.flags = task.flags | Win32::TaskScheduler::DISABLED
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
      # Even though this is an assignment, the API for
      # Win32::TaskScheduler ends up appending this trigger to the
      # list of triggers for the task, while #add_trigger is only able
      # to replace existing triggers. *shrug*
      task.trigger = translate_hash_to_trigger(trigger_hash)
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
    @task = PuppetX::PuppetLabs::ScheduledTask::TaskScheduler2V1Task.new(resource[:name], dummy_time_trigger)
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
    return false if translate_hash_to_trigger(desired_trigger)['trigger_type'] != translate_hash_to_trigger(current_trigger)['trigger_type']

    desired = desired_trigger.dup
    desired['start_date']  ||= current_trigger['start_date']  if current_trigger.has_key?('start_date')
    desired['every']       ||= current_trigger['every']       if current_trigger.has_key?('every')
    desired['months']      ||= current_trigger['months']      if current_trigger.has_key?('months')
    desired['on']          ||= current_trigger['on']          if current_trigger.has_key?('on')
    desired['day_of_week'] ||= current_trigger['day_of_week'] if current_trigger.has_key?('day_of_week')

    translate_hash_to_trigger(current_trigger) == translate_hash_to_trigger(desired)
  end

  def self.normalized_date(date_string)
    date = Date.parse("#{date_string}")
    "#{date.year}-#{date.month}-#{date.day}"
  end

  def self.normalized_time(time_string)
    Time.parse("#{time_string}").strftime('%H:%M')
  end

  def dummy_time_trigger
    now = Time.now
    {
      'flags'                   => 0,
      'random_minutes_interval' => 0,
      'end_day'                 => 0,
      'end_year'                => 0,
      'minutes_interval'        => 0,
      'end_month'               => 0,
      'minutes_duration'        => 0,
      'start_year'              => now.year,
      'start_month'             => now.month,
      'start_day'               => now.day,
      'start_hour'              => now.hour,
      'start_minute'            => now.min,
      'trigger_type'            => Win32::TaskScheduler::ONCE,
    }
  end

  def translate_hash_to_trigger(puppet_trigger)
    trigger = dummy_time_trigger

    if puppet_trigger['enabled'] == false
      trigger['flags'] |= Win32::TaskScheduler::TASK_TRIGGER_FLAG_DISABLED
    else
      trigger['flags'] &= ~Win32::TaskScheduler::TASK_TRIGGER_FLAG_DISABLED
    end

    extra_keys = puppet_trigger.keys.sort - ['index', 'enabled', 'schedule', 'start_date', 'start_time', 'every', 'months', 'on', 'which_occurrence', 'day_of_week', 'minutes_interval', 'minutes_duration']
    self.fail "Unknown trigger option(s): #{Puppet::Parameter.format_value_for_display(extra_keys)}" unless extra_keys.empty?
    self.fail "Must specify 'start_time' when defining a trigger" unless puppet_trigger['start_time']

    case puppet_trigger['schedule']
    when 'daily'
      trigger['trigger_type'] = Win32::TaskScheduler::DAILY
      trigger['type'] = {
        'days_interval' => Integer(puppet_trigger['every'] || 1)
      }
    when 'weekly'
      trigger['trigger_type'] = Win32::TaskScheduler::WEEKLY
      trigger['type'] = {
        'weeks_interval' => Integer(puppet_trigger['every'] || 1)
      }

      days_of_week = puppet_trigger['day_of_week'] || PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Day.names
      trigger['type']['days_of_week'] = PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Day.names_to_bitmask(days_of_week)
    when 'monthly'
      trigger['type'] = {
        'months' => PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Month.indexes_to_bitmask(puppet_trigger['months'] || (1..12).to_a),
      }

      if puppet_trigger.keys.include?('on')
        if puppet_trigger.has_key?('day_of_week') or puppet_trigger.has_key?('which_occurrence')
          self.fail "Neither 'day_of_week' nor 'which_occurrence' can be specified when creating a monthly date-based trigger"
        end

        trigger['trigger_type'] = Win32::TaskScheduler::MONTHLYDATE
        trigger['type']['days'] = PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Days.indexes_to_bitmask(puppet_trigger['on'])
      elsif puppet_trigger.keys.include?('which_occurrence') or puppet_trigger.keys.include?('day_of_week')
        self.fail 'which_occurrence cannot be specified as an array' if puppet_trigger['which_occurrence'].is_a?(Array)
        %w{day_of_week which_occurrence}.each do |field|
          self.fail "#{field} must be specified when creating a monthly day-of-week based trigger" unless puppet_trigger.has_key?(field)
        end

        trigger['trigger_type']         = Win32::TaskScheduler::MONTHLYDOW
        trigger['type']['weeks']        = PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Occurrence.name_to_constant(puppet_trigger['which_occurrence'])
        trigger['type']['days_of_week'] = PuppetX::PuppetLabs::ScheduledTask::Trigger::V1::Day.names_to_bitmask(puppet_trigger['day_of_week'])
      else
        self.fail "Don't know how to create a 'monthly' schedule with the options: #{puppet_trigger.keys.sort.join(', ')}"
      end
    when 'once'
      self.fail "Must specify 'start_date' when defining a one-time trigger" unless puppet_trigger['start_date']

      trigger['trigger_type'] = Win32::TaskScheduler::ONCE
    else
      self.fail "Unknown schedule type: #{puppet_trigger["schedule"].inspect}"
    end

    integer_interval = -1
    if puppet_trigger['minutes_interval']
      integer_interval = Integer(puppet_trigger['minutes_interval'])
      self.fail 'minutes_interval must be an integer greater or equal to 0' if integer_interval < 0
      trigger['minutes_interval'] = integer_interval
    end

    integer_duration = -1
    if puppet_trigger['minutes_duration']
      integer_duration = Integer(puppet_trigger['minutes_duration'])
      self.fail 'minutes_duration must be an integer greater than minutes_interval and equal to or greater than 0' if integer_duration <= integer_interval && integer_duration != 0
      trigger['minutes_duration'] = integer_duration
    end

    if integer_interval > 0 && integer_duration == -1
      minutes_in_day = 1440
      integer_duration = minutes_in_day
      trigger['minutes_duration'] = minutes_in_day
    end

    if integer_interval >= integer_duration && integer_interval > 0
      self.fail 'minutes_interval cannot be set without minutes_duration also being set to a number greater than 0'
    end

    if start_date = puppet_trigger['start_date']
      start_date = Date.parse(start_date)
      self.fail "start_date must be on or after 1753-01-01" unless start_date >= Date.new(1753, 1, 1)

      trigger['start_year']  = start_date.year
      trigger['start_month'] = start_date.month
      trigger['start_day']   = start_date.day
    end

    start_time = Time.parse(puppet_trigger['start_time'])
    trigger['start_hour']   = start_time.hour
    trigger['start_minute'] = start_time.min

    trigger
  end

  def validate_trigger(value)
    value = [value] unless value.is_a?(Array)

    value.each do |t|
      if t.has_key?('index')
        self.fail "'index' is read-only on scheduled_task triggers and should be removed ('index' is usually provided in puppet resource scheduled_task)."
      end

      if t.has_key?('enabled')
        self.fail "'enabled' is read-only on scheduled_task triggers and should be removed ('enabled' is usually provided in puppet resource scheduled_task)."
      end

      translate_hash_to_trigger(t)
    end

    true
  end

  private

  def scheduler_trigger_types
    [
      Win32::TaskScheduler::TASK_TIME_TRIGGER_DAILY,
      Win32::TaskScheduler::TASK_TIME_TRIGGER_WEEKLY,
      Win32::TaskScheduler::TASK_TIME_TRIGGER_MONTHLYDATE,
      Win32::TaskScheduler::TASK_TIME_TRIGGER_MONTHLYDOW,
      Win32::TaskScheduler::TASK_TIME_TRIGGER_ONCE
    ]
  end
end
