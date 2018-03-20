# @api private
module PuppetX
module PuppetLabs
module ScheduledTask

module Trigger
  class Duration
    # From https://msdn.microsoft.com/en-us/library/windows/desktop/aa381850(v=vs.85).aspx
    # https://en.wikipedia.org/wiki/ISO_8601#Durations
    #
    # The format for this string is PnYnMnDTnHnMnS, where nY is the number of years, nM is the number of months,
    # nD is the number of days, 'T' is the date/time separator, nH is the number of hours, nM is the number of minutes,
    # and nS is the number of seconds (for example, PT5M specifies 5 minutes and P1M4DT2H5M specifies one month,
    # four days, two hours, and five minutes)
    def self.to_hash(duration)
      regex = /^P((?'year'\d+)Y)?((?'month'\d+)M)?((?'day'\d+)D)?(T((?'hour'\d+)H)?((?'minute'\d+)M)?((?'second'\d+)S)?)?$/

      matches = regex.match(duration)
      return nil if matches.nil?

      {
        :year => matches['year'],
        :month => matches['month'],
        :day => matches['day'],
        :minute => matches['minute'],
        :hour => matches['hour'],
        :second => matches['second'],
      }
    end

    def self.hash_to_seconds(value)
      return 0 if value.nil?
      time = 0
      # Note - the Year and Month calculations are approximate
      time = time + value[:year].to_i   * (365.2422 * 24 * 60**2)      unless value[:year].nil?
      time = time + value[:month].to_i  * (365.2422 * 2 * 60**2)       unless value[:month].nil?
      time = time + value[:day].to_i    * 24 * 60**2                   unless value[:day].nil?
      time = time + value[:hour].to_i   * 60**2                        unless value[:hour].nil?
      time = time + value[:minute].to_i * 60                           unless value[:minute].nil?
      time = time + value[:second].to_i                                unless value[:second].nil?

      time.to_i
    end

    def self.to_minutes(value)
      return 0 if value.nil?
      return 0 unless value.is_a?(String)
      return 0 if value.empty?

      duration = hash_to_seconds(to_hash(value))

      duration / 60
    end
  end

  def string_to_int(value)
    return 0 if value.nil?
    return value if value.is_a?(Numeric)
    raise ArgumentError.new('value must be a String') unless value.is_a?(String)

    value.to_i
  end
  module_function :string_to_int

  def string_to_date(value)
    return nil if value.nil?
    raise ArgumentError.new('value must be a String') unless value.is_a?(String)
    return nil if value.empty?

    DateTime.parse(value)
  end
  module_function :string_to_date

  def iso8601_datetime(year, month, day, hour, minute)
    DateTime.new(year, month, day, hour, minute, 0).iso8601
  end
  module_function :iso8601_datetime

  # TASK_TRIGGER structure approximated as Ruby hash
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383618(v=vs.85).aspx
  class V1
    # iTrigger is a COM ITrigger instance
    def self.from_iTrigger(iTrigger)
      require 'puppet/util/windows/taskscheduler' # Needed for the WIN32::ScheduledTask flag constants
      trigger_flags = 0
      trigger_flags = trigger_flags | Win32::TaskScheduler::TASK_TRIGGER_FLAG_HAS_END_DATE unless iTrigger.Endboundary.empty?
      # There is no corresponding setting for the V1 flag TASK_TRIGGER_FLAG_KILL_AT_DURATION_END
      trigger_flags = trigger_flags | Win32::TaskScheduler::TASK_TRIGGER_FLAG_DISABLED unless iTrigger.Enabled

      start_boundary = Trigger.string_to_date(iTrigger.StartBoundary)
      end_boundary = Trigger.string_to_date(iTrigger.EndBoundary)

      v1trigger = {
        'start_year'              => start_boundary.year,
        'start_month'             => start_boundary.month,
        'start_day'               => start_boundary.day,
        'end_year'                => end_boundary ? end_boundary.year : 0,
        'end_month'               => end_boundary ? end_boundary.month : 0,
        'end_day'                 => end_boundary ? end_boundary.day : 0,
        'start_hour'              => start_boundary.hour,
        'start_minute'            => start_boundary.minute,
        'minutes_duration'        => Duration.to_minutes(iTrigger.Repetition.Duration),
        'minutes_interval'        => Duration.to_minutes(iTrigger.Repetition.Interval),
        'flags'                   => trigger_flags,
        'random_minutes_interval' => Trigger.string_to_int(iTrigger.Randomdelay)
      }

      case iTrigger.ole_type.to_s
        when 'ITimeTrigger'
          v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_ONCE
          v1trigger['type'] = { 'once' => nil }
        when 'IDailyTrigger'
          v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_DAILY
          v1trigger['type'] = {
            'days_interval' => Trigger.string_to_int(iTrigger.DaysInterval)
          }
        when 'IWeeklyTrigger'
          v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_WEEKLY
          v1trigger['type'] = {
            'weeks_interval' => Trigger.string_to_int(iTrigger.WeeksInterval),
            'days_of_week'   => Trigger.string_to_int(iTrigger.DaysOfWeek)
          }
        when 'IMonthlyTrigger'
          v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_MONTHLYDATE
          v1trigger['type'] = {
            'days'   => Trigger.string_to_int(iTrigger.DaysOfMonth),
            'months' => Trigger.string_to_int(iTrigger.MonthsOfYear)
          }
        when 'IMonthlyDOWTrigger'
          v1trigger['trigger_type'] = :TASK_TIME_TRIGGER_MONTHLYDOW
          v1trigger['type'] = {
            'weeks'        => Trigger.string_to_int(iTrigger.WeeksOfMonth),
            'days_of_week' => Trigger.string_to_int(iTrigger.DaysOfWeek),
            'months'       => Trigger.string_to_int(iTrigger.MonthsOfYear)
          }
        else
          raise Error.new(_("Unknown trigger type %{type}") % { type: iTrigger.ole_type.to_s })
      end

      v1trigger
    end
  end
end
end
end
end
